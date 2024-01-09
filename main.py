from flask import Flask, request, jsonify
import morfeusz2

app = Flask(__name__)
morfeusz = morfeusz2.Morfeusz()

@app.route('/steem', methods=['GET'])  
def steem():  
    text = request.args.get('text', default = '', type = str)  
    analysis = morfeusz.analyse(text)  
    lemmatized_words = [interp[2][0][0] for seg, orth, interp in analysis]  
    lemmatized_text = ' '.join(lemmatized_words)  
    return jsonify(original_text=text, lemmatized_text=lemmatized_text)  

if __name__ == '__main__':  
    app.run(host='0.0.0.0', port=5000)  
