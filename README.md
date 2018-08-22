# online-presenter

Ever wanted to present google slides online without screen sharing or asking your viewers to change to next slide on their side? This tool can help you! Your viewers will see new slide immediately when you'll change it on your side.

## Installation

`apt-get install libmojolicious-perl`

## Running

`perl online-presenter.pl daemon`

## Usage

1. Create subdirectory with name of your presentation inside public/presentations/
2. Download all slides of your presentation as SVG and place inside public/presentations/PRESENTATION_NAME/. Name of first slide should start with zero: 0.svg, 1.svg, 2.svg and so on
3. Run webapp
4. Give url of the presentation to your viewers: http://hostname:3000/view/PRESENTATION_NAME
5. Open presenter interface in your browser: http://hostname:3000/present/PRESENTATION_NAME
6. Ask viewers to press F11 and relax
