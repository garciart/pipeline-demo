import csv

from flask import Flask, render_template

app = Flask(__name__)


@app.route('/')
def say_hello():
    return '<h1>Hello, World!</h1>'


@app.route('/data')
def show_data():
    with open("data.csv") as file:
        reader = csv.reader(file)
        return render_template("data.html", csv=reader)


if __name__ == '__main__':
    app.run()
