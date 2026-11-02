import unittest
from cms_bridge_worker import extract_result, map_verdict, multipart_file

class WorkerParsingTests(unittest.TestCase):
    def test_accepted(self):
        sample={'details':[{'idx':0,'testcases':[{'outcome':'Correct'},{'outcome':'Correct'}]}]}
        self.assertEqual(extract_result(sample),{'status':'Accepted','passed':2,'total':2})
    def test_wrong_answer(self):
        sample={'details':[{'outcome':'Correct'},{'outcome':'Not correct'}]}
        self.assertEqual(extract_result(sample),{'status':'Wrong Answer','passed':1,'total':2})
    def test_unknown_not_accepted(self):
        self.assertEqual(map_verdict(['Correct','Unknown outcome']),'Judge Error')
        self.assertIsNone(extract_result({'details':[]}))
    def test_multipart(self):
        body,ctype = multipart_file('task.%l','print(1)','task.py','Python 3 / CPython')
        self.assertIn(b'filename="task.py"',body)
        self.assertIn(b'name="task.%l"',body)
        self.assertIn(b'name="language"',body)
        self.assertIn(b'Python 3 / CPython',body)
        self.assertIn('multipart/form-data',ctype)

if __name__=='__main__': unittest.main()
