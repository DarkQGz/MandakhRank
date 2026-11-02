"""Executed INSIDE the restricted container."""
import contextlib, io, json, sys
class LimitedOutput(io.StringIO):
    size = 0
    def write(self, text):
        self.size += len(text.encode('utf-8', 'replace'))
        if self.size > 16384: raise OverflowError('Output limit exceeded')
        return super().write(text)
job = json.loads(sys.stdin.read())
output = LimitedOutput()
sys.stdin = io.StringIO(job['stdin'])
error = None
try:
    with contextlib.redirect_stdout(output):
        exec(compile(job['code'], 'solution.py', 'exec'), {'__name__':'__main__'})
except BaseException as exc:
    error = type(exc).__name__
sys.__stdout__.write(json.dumps({'output':output.getvalue(), 'error':error}))
