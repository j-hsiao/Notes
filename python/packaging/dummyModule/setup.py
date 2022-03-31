from setuptools import setup

# setup(
#     py_modules=['top', 'sub.sub'],
#     name='somemodule',
#     author='me',
#     author_email='secret@example.com'
# )

setup(
    package_dir={'somemodule': ''},
    #py_modules=['somemodule.top', 'somemodule.sub.sub', 'somemodule.__main__'],
    packages=['somemodule', 'somemodule.sub'],
    name='somemodule',
    author='me',
    author_email='secret@example.com',
    install_requires=['numpy']
)
