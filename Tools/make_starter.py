"""Create an original, source-scoped starter lesson. No copied book prose."""
import json
from pathlib import Path
root = Path(__file__).resolve().parents[1]
sources = [
    dict(id='book', title='Tali Sharot · The Influential Mind (2017)',
         url='https://us.macmillan.com/books/9781627792660/theinfluentialmind/',
         locator='Publisher-provided prologue, especially the discussion of persuasion and seven factors.',
         scope='Establishes the book’s framework and priors as its first factor. The complete first chapter was not supplied or reviewed; this is an introductory concept lesson, not a chapter-complete summary.'),
    dict(id='research', title='Kappes, Harvey, Lohrenz, Montague & Sharot (2019)',
         url='https://affectivebrain.com/wp-content/uploads/2019/12/s41593-019-0549-2.pdf',
         locator='Confirmation bias in the utilization of others’ opinion strength · Nature Neuroscience · DOI 10.1038/s41593-019-0549-2 · abstract, task description and discussion.',
         scope='Supporting research published after the book. Participants used others’ confidence differently when it agreed versus disagreed with an existing judgment. It does not test the fictional college program or prove that finding common ground guarantees persuasion.')
]
def page(id,kind,role,title,text,image=None,description=None,refs=None):
    return dict(id=id,kind=kind,role=role,title=title,text=text,imageAsset=image,
                imageBase64=None,imageDescription=description,sourceIDs=refs or [])
pages = [
page('welcome','intro','guide','The Prior Problem',
     'What you already believe can shape how you receive new information. This is a starting point for exploring priors in Tali Sharot’s The Influential Mind. First, meet two students looking at one report. Their college, experiences, and report are invented for this lesson. Watch what each person notices—and what each person overlooks.',
     'priors-setup','Malik and Elena sit across a college meeting table with a shared laptop.', ['book','research']),
page('before','story','storyteller','Before the report',
     'Malik arrived at the student council meeting with a yellow notebook and a clear opinion. The college’s work-study program deserved another year. Working during school had helped him pay for transport and learn how to handle responsibility.\n\nAcross the table, Elena opened her laptop. She wanted the program reduced. Her friend Rosa had taken extra shifts, missed assignments, and eventually dropped a class. When Elena pictured student employment, she pictured Rosa falling asleep over a textbook.\n\nNeither had opened today’s report. Both already expected to know what it would mean.',
     'priors-setup','Malik in a mustard overshirt and Elena in a sage sweater review a laptop before discussing the report.'),
page('same','story','storyteller','One report. Two readings.',
     'The report offered a complicated picture. Some participants described useful skills and greater confidence. Others described fatigue and difficulty finding time to study. Its authors recommended further investigation; it could not establish that the program caused either outcome.\n\nMalik tapped the section about confidence. “That’s what I’m talking about. It gives people a foothold.”\n\nElena pointed to the complaints about fatigue. “And that’s what worries me. Students already have enough to carry.”\n\nBoth comments referred to something actually on the page. But each had started with the passage that fit an existing expectation.',
     'priors-conflict','Each student points to a different part of the same fictional report.'),
page('argument','story','storyteller','More facts. Less listening.',
     'Malik read another positive comment aloud. Elena answered with another complaint. Soon they were talking faster than either could listen.\n\n“You’re ignoring the benefit,” Malik said.\n\n“You’re ignoring the cost,” Elena replied.\n\nTheir adviser asked a quiet question: “Which finding would make each of you reconsider?”\n\nMalik looked down. He had been collecting support for keeping the program, not deciding what might count against it. Elena realized she had done the same in the other direction.\n\nThe report had become ammunition. Neither had treated it as a question that was still open.',
     'priors-conflict','Malik and Elena disagree politely, holding papers that emphasize different findings.'),
page('listen','story','storyteller','What came into the room?',
     'Elena explained what had happened to Rosa. Malik’s expression changed. He had assumed Elena disliked work itself. Now he understood her concern about overload.\n\nThen Malik described the supervisor who had taught him to plan a shift and speak up when he needed help. Elena had assumed he cared only about keeping a popular program. Now she understood the opportunity he wanted to protect.\n\nTheir experiences were different. Their aim was similar: help students succeed.\n\nThat did not settle the argument. It gave them a reason to examine the whole report instead of defending their first reactions.',
     'priors-resolution','The students listen to one another and begin looking at the report together.'),
page('revise','story','storyteller','A better question',
     '“What if we looked at which students were struggling, and how many hours they worked?” Malik asked.\n\n“And compared students with similar workloads,” Elena added. “Maybe we need better evidence before deciding.”\n\nThey drafted a small trial with work-hour limits and academic check-ins, then agreed to evaluate both benefits and problems. Malik wrote down what would make him favor reducing the program. Elena wrote down what would make her favor keeping it.\n\nThey had not magically become unbiased. They had changed the task—from winning an argument to testing an idea.',
     'priors-resolution','Malik and Elena collaborate over one report, considering both benefits and concerns.'),
page('distinction','explanation','guide','Beliefs are a starting point',
     'A prior is a belief held before new information arrives. It is not automatically a mistake. Confirmation bias is the tendency to favor information that fits an existing view.\n\nA later study involving Sharot found that people used others’ confidence more when those opinions agreed with their earlier judgments.\n\nOur story illustrates selective interpretation. Shared goals and the adviser’s question are teaching strategies we added, not a guaranteed persuasion method tested by that study. Different conclusions can also reflect legitimate differences in values or evidence quality. Facts still matter.',
     refs=['book','research']),
page('takeaway','takeaway','guide','Notice your starting point',
     'Before defending a conclusion, name what you already believe. Ask what evidence could change your mind. Then examine the strongest support and challenge with the same care.\n\nWhen listening to someone else, understand their starting point too. Common ground can open a conversation; it does not decide what is true.',
     refs=['book','research'])
]
questions = [
 dict(id='recognition',prompt='A manager expects remote work to fail. A mixed report contains benefits and problems. She highlights every problem and dismisses the benefits without checking their quality. What best explains this pattern?',correctChoiceID='selective',choices=[
  dict(id='selective',text='Her prior belief is influencing which evidence she takes seriously.',feedback='Yes. Favoring evidence because it fits an existing view is confirmation bias. The problem is unequal scrutiny, not merely having an initial belief.'),
  dict(id='certain',text='The report proves remote work is ineffective.',feedback='A mixed report does not establish that conclusion. We would need to assess the evidence. Her selective handling of it is the pattern being tested.'),
  dict(id='badprior',text='Any belief formed before reading a report is irrational.',feedback='Priors can reflect useful experience. Bias arises when the new evidence is handled unevenly because of the existing belief.')]),
 dict(id='transfer',prompt='You favor a new tutoring program. Your friend doubts it. Which next step best helps you both evaluate the evidence fairly?',correctChoiceID='test',choices=[
  dict(id='pile',text='Send only success stories until your friend agrees.',feedback='Success stories may be useful evidence, but selecting only one side repeats the problem. Look at credible challenges as well as support.'),
  dict(id='agree',text='Find a shared goal and assume that means the program works.',feedback='A shared goal may help the discussion. It cannot establish whether a program works. That still needs evidence.'),
  dict(id='test',text='Name your starting beliefs and agree on findings that would make each of you reconsider.',feedback='Yes. This makes the beliefs and standards explicit. Then assess the quality of both supporting and challenging evidence. It helps structure the evaluation; it does not guarantee agreement.')])
]
book = dict(id='influential-mind', title='The Influential Mind',author='Tali Sharot',
 synopsis='Explore how existing beliefs shape the way we receive information. Start with a fictional college meeting, then try the idea in a new situation.',
 coverageNote='Starter collection: one introductory lesson on priors. Grounded in the publisher’s prologue and a separately identified 2019 research paper. The full book and Chapter 1 have not been reviewed; completion here means completion of the available lesson only.',
 sources=sources,lessons=[dict(id='priors',revision=1,title='The Prior Problem',subtitle='Why evidence does not enter an empty mind',estimatedMinutes=5,
 scopeNote='Original teaching story. Introductory coverage of priors; not an exhaustive chapter summary. Fictional report findings are not research results.',pages=pages,questions=questions)])
package = dict(formatVersion=1,book=book)
payload = json.dumps(package,ensure_ascii=False,indent=2)+'\n'
(root/'LifeIsLearned/Resources/starter.json').write_text(payload)
(root/'Example-Lesson-Package.json').write_text(payload)
print('Narrated word count:',sum(len((p['title']+' '+p['text']).split()) for p in pages))
