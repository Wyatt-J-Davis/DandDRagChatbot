# Bug Fixes and Improvements to Flutter Implementation of TTRPG Chatbot

The fixes and improvements fall under two catagories: **functional**, and **aesthetic**. I will outline each in seperate sections. 

## Functional Bugs and Improvements
- Vectorized database is not properly detected by pieces of application UI during consecutive runs of the executable. When I restart the application after vectorizing in the previvous running of the app I have the option to upload notes instead of re-uplaod and the reference note file is no longer displayed in the settings. I can still ask questions in the Q&A section and I get answers with references, but in the notes page I have no option to "import". I expect the application state with regard to there being a vectorized database to be the same accross re-runs.
- Notes are not persistnetly saved when the application is closed or restarted. When I reopen the app I expect the notes that I had imported or typed in before to be reloaded in but that is not happening.
- Switching between pages kills long running processes like inference and vectorization, which leads to a poor user experience as it takes time for these processes to restart when switching back to them. I expect these long running operations to get executed as subprocesses so they do not get killed by the user switching pages.
- Position of editor scroll bar is not currenlty persistent accross page switches or app re-runs. I expect the scroll bar to be in the same place I left it when I return to that page.
- When I switch between pages the chat history gets reset and is blank. I would like the chat to be persistent across page switches.
- When generating a summary I get the following error: "Raw notes not found. Upload notes on the main page first" when I know that the notes have been uploaded and vectorized. I expect the summary feature to work properly when notes are availible and vectorized.
- When I vectorize the notes in the note editor page, I see a progress bar come up but no progress is ever made. I expect the edited notes to be able to be vectorized without any issues.
- Party member names are not persistent accross app re-runs. I expect this setting to be persistent so I don't have to update it each time I run the app.
- Dark mode toggle for note editor is not persistent accross app re-runs. I would like this setting to persist across app re-runs so I don't have to change it each time
- The sources for the chatbot reply currelty are called "soruce1", "source2", etc. I expect the name of these source buttons to be the date associated with the chunk. This should be in the metadata of the chunk created during semantic chunking.
- The note editor should be able to export the notes to a docx or txt file like the streamlit version of the app.
- "Import" option for note editor is irrelevant. Any notes that are vectorized should appear in this section, it is okay even if it ovverwrites what is already there. 
- When vectorising notes, play the assets/Magical_Effect_Loading.json animation right above the loading bar in the settings popup.

## Aesthetic/Visual Issues and Improvments:
- I don't like how much room the settings bar(Model, temperature, party members, upload notes option) takes up in the Q&A page. I expect that there should be a settings icon in the lower left of the page bar that opens a pop-up settings menue with the same options as the current settings bar. The room taken up by this setting currently infringes on the chat window unessesariy, I would like more room for that. That settings option should be availible accross all three pages.
- I Would like the page icons to be replaced by the following: magic orb instead of text chat bubble for Q&A, a typical starry effect associated with AI generation for the summary page rather than the page icon, and a quill for the note editor page.
- I would like the initial chat bubble to start out in the middle of the page like most popular chatbot interfaces. Currently it starts at the botom. I would also like a large wizard emoji to be on top of the initial chat entry box, sort of like the llama is in the ollama chat interface. 
- Currenlty the chatbot responses get pasted into the chat window all at once. I would like the chat to stream in at intervals of .02 seconds per character rather than get pasted into the chat bubble all at once. 
- During bot inference, there is currently a generic load bar that flashes at the bottom of the screen. I would like instead for the the lottie animation (assets/star-magic.json) to play under the most recent user query in the center of the chat window.It should dissapear when the bot begins streaming its response.
- The "vectorize" options are pretty intrusive in the note taking section. I would like those to be moved to the top of the page by the dark mode toggler
- Executable should have wizard emoji as icon in task bar. Use the icon.ico file from assets
- There appears to be a toggle for "note taker" in the settings but it is not currenlty labeled as such. I am not sure if it works.
- None of the settings options are labeled. I would like them all to have labels (model, temperature, party members, etc.).




