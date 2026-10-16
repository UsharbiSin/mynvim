#!/usr/bin/env python3
"""Real attached-UI regression for F10; only runs temporary Python fixtures."""
import pathlib
import signal
import sys
import tempfile
import time

import pynvim

REPO = pathlib.Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else pathlib.Path(__file__).resolve().parents[1]


def timeout(_signum, _frame):
    raise TimeoutError('F10 terminal regression exceeded 35 seconds')


signal.signal(signal.SIGALRM, timeout)
signal.alarm(35)
nvim = None
try:
    with tempfile.TemporaryDirectory(prefix='f10 terminal test ') as directory:
        root = pathlib.Path(directory)
        nvim = pynvim.attach('child', argv=['nvim', '--embed', '-u', 'NONE', '-i', 'NONE'])
        nvim.ui_attach(100, 30, rgb=True)
        nvim.exec_lua('''
            vim.opt.runtimepath:prepend(...)
            vim.g.is_win = 0
            vim.opt.swapfile = false
            vim.opt.hidden = true
            vim.keymap.set('n', '<F10>', require('core.runner').run_current)
        ''', str(REPO))

        def mode():
            return nvim.api.get_mode()['mode']

        def wait(check, message, seconds=4):
            deadline = time.monotonic() + seconds
            while time.monotonic() < deadline:
                if check():
                    return
                time.sleep(0.015)
            raise AssertionError(message + '; mode=' + mode())

        def text(buf):
            return '\n'.join(nvim.api.buf_get_lines(buf, 0, -1, False))

        def visible(buf, win):
            return (nvim.api.buf_is_valid(buf) and nvim.api.win_is_valid(win)
                    and nvim.api.win_get_buf(win).number == buf)

        def start(name, source):
            nvim.input('<C-\\><C-N>')
            wait(lambda: mode() in ('n', 'nt'), 'could not leave input mode')
            path = root / (name + '.py')
            path.write_text(source, encoding='utf-8')
            nvim.command('edit ' + nvim.funcs.fnameescape(str(path)))
            nvim.current.buffer.options['filetype'] = 'python'
            old_windows = {win.handle for win in nvim.windows}
            nvim.input('<F10>')
            wait(lambda: nvim.current.buffer.options['buftype'] == 'terminal'
                 and nvim.current.window.handle not in old_windows,
                 name + ': F10 did not create a terminal split')
            buf, win = nvim.current.buffer.number, nvim.current.window.handle
            job = nvim.api.buf_get_var(buf, 'terminal_job_id')
            return buf, win, job

        def finished(job):
            return nvim.funcs.jobwait([job], 0)[0] != -1

        def ended(buf, win, job, output):
            wait(lambda: finished(job), 'fixture process did not exit')
            wait(lambda: mode() in ('n', 'nt'), 'finished terminal remained in input mode')
            assert visible(buf, win), 'finished result window disappeared'
            assert output in text(buf), 'expected output was lost'

        buf, win, job = start('quick success', "print('QUICK OUTPUT')\n")
        ended(buf, win, job, 'QUICK OUTPUT')
        for keys in ('hjkl', 'ih', 'al'):
            nvim.input(keys)
            wait(lambda: mode() in ('n', 'nt'), 'closed terminal reentered input mode')
            assert visible(buf, win), 'keys ' + repr(keys) + ' closed the result'
            assert 'QUICK OUTPUT' in text(buf), 'navigation lost output'
        print('PASS: quick exit, ordinary keys, i/a reentry preserve output')

        buf, win, job = start('nonzero exit', "import sys\nprint('ERROR OUTPUT')\nsys.exit(7)\n")
        ended(buf, win, job, 'ERROR OUTPUT')
        nvim.input('hjkl')
        assert visible(buf, win), 'nonzero result closed on ordinary keys'
        print('PASS: nonzero exit retains output')

        buf, win, job = start('interactive input',
                             "value = input('INPUT READY> ')\nprint('RECEIVED=' + value)\n")
        wait(lambda: 'INPUT READY>' in text(buf) and mode() == 't',
             'interactive fixture did not enter terminal input mode')
        nvim.input('q<CR>')
        ended(buf, win, job, 'RECEIVED=q')
        nvim.input('q')
        wait(lambda: not visible(buf, win), 'ordinary q did not close finished output')
        print('PASS: running program receives q; completed output closes with q')

        release = root / 'release background exit'
        source = ("import pathlib, time\n"
                  f"release = pathlib.Path({str(release)!r})\n"
                  "print('BACKGROUND READY', flush=True)\n"
                  "deadline = time.monotonic() + 5\n"
                  "while not release.exists() and time.monotonic() < deadline:\n"
                  "    time.sleep(0.01)\n"
                  "print('BACKGROUND DONE')\n")
        buf, win, job = start('background exit', source)
        wait(lambda: 'BACKGROUND READY' in text(buf), 'background fixture not ready')
        nvim.input('<C-\\><C-N>')
        wait(lambda: mode() in ('n', 'nt'), 'could not leave running terminal')
        nvim.command('wincmd p')
        nvim.command('enew')
        editing = nvim.current.buffer.number
        nvim.input('iKEEP TYPING')
        wait(lambda: mode() == 'i', 'other buffer did not enter Insert mode')
        release.touch()
        wait(lambda: finished(job), 'background fixture did not exit')
        wait(lambda: 'BACKGROUND DONE' in text(buf), 'background output missing')
        assert mode() == 'i', 'background exit interrupted another buffer Insert mode'
        assert nvim.current.buffer.number == editing, 'background exit stole focus'
        assert visible(buf, win), 'background result window disappeared'
        print('PASS: background exit preserves other buffer focus and Insert mode')
        print('ALL F10 TERMINAL TESTS PASSED')
finally:
    signal.alarm(0)
    if nvim is not None:
        try:
            nvim.command('qa!')
        except (EOFError, OSError):
            pass
        nvim.close()
