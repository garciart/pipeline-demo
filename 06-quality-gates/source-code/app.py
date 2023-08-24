import csv

from flask import Flask, render_template
from flask_wtf import CSRFProtect

app = Flask(__name__)
csrf = CSRFProtect()
csrf.init_app(app)  # Compliant


@app.route('/', methods=['POST'])  # Compliant
def say_hello():
    return '<h1>Hello, World!</h1>'


@app.route('/data', methods=['POST'])  # Compliant
def show_data():
    with open("data.csv") as file:
        reader = csv.reader(file)
        return render_template("data.html", csv=reader)


if __name__ == '__main__':
    app.run()
