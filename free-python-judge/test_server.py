import base64, unittest
from unittest.mock import patch
import server
class Tests(unittest.TestCase):
    def test_base64(self):
        self.assertEqual(server.decode(base64.b64encode(b'3 7\n').decode()),'3 7\n')
        with self.assertRaises(ValueError):server.decode('not-base64!')
    def test_verdict(self):
        class Process:
            returncode=0
            stdout='{"output":"10\\n","error":null}'
        with patch('server.subprocess.run',side_effect=[Process(),Process()]):
            server.sem.acquire()
            server.execute('a','print(10)','3 7\n','10\n')
            self.assertEqual(server.jobs['a'][0],3)
    def test_wrong_answer(self):
        class Process:
            returncode=0
            stdout='{"output":"11\\n","error":null}'
        with patch('server.subprocess.run',side_effect=[Process(),Process()]):
            server.sem.acquire()
            server.execute('b','print(11)','3 7\n','10\n')
            self.assertEqual(server.jobs['b'][0],4)
if __name__=='__main__':unittest.main()
