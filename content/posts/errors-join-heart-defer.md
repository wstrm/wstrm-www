---
title: "errors.Join ❤️ defer"
date: 2023-03-08T09:40:00+02:00
---

A common gripe I've had with Go is that the mantra is "you should handle
errors", but at the same time the ergonomics of handling errors from
`(io.ReadCloser).Close()` in a `defer` call is cumbersome. But fear no more!
With the Go 1.20 release, there's a nifty way to handle this with the new
[`errors.Join`](https://pkg.go.dev/errors#Join).

<!--more-->

Let me first explain a bit about the issue. Usually if you want to do the
"right" thing and check for errors in a `defer` call, you end with something
like this:

```
func example(r io.ReadCloser) (err error) {
    // We need this big anonymous function that takes up a bunch of
    // precious lines...
    defer func() {
        // Ugghh, need to check for the error and then set it D:
        cerr := r.Close()
        if cerr != nil {
            err = cerr
        }
    }

	// ... code that reads from r ...
}
```

This approach has a shortcoming. If the `err` variable was set
before the `defer` function is called we'll override the original error with our
`(io.ReadCloser).Close()` call error.

Even worse, if you're lazy and you figured the error check is not worth the
amount of work, you end up with just ignoring the error altogether:

```
func example(r io.ReadCloser) (err error) {
    defer r.Close() // Oh no, we'll never know if this errors :(

	// ... code that reads from r ...
}
```

This is pretty common among the codebases I've seen (and I'm also an offender of
this). It's not really the proper way to do things. You should either handle the
error, or at least log it so you're aware of that there are issues closing the
reader for whatever reason.

## Luckily we now have errors.Join 🤓

With the Go 1.20 release, you can now join errors so that you don't override the
original error with the `(io.ReadCloser).Close()` error and not need to make the
repetitive `if err != nil` check all the time. The new function
[`errors.Join`](https://pkg.go.dev/errors#Join) will only return errors that are
non-`nil`. And if all are `nil`, it'll of course return `nil`. This perfectly
fits the use case of handling close errors in a `defer`! 💥

Let's create a new anonymous `defer` function, and just pass along our original
`err` and the `(io.ReadCloser).Close()` error:

```
func example(r io.ReadCloser) (err error) {
	defer func() {
		err = errors.Join(err, r.Close()) // Magic!
	}()

	// ... code that reads from r ...
}

```

Psst, here's a full working example: https://go.dev/play/p/J-rkdh0jYme

Now, if any of the errors occur, the `err` will be set. In the case where both
errors, we get a new `error` where they are joined with a `\n` delimiter:

```
origErr := errors.New("original error")
closeErr := errors.New("close error")
joinedErr := errors.Join(origErr, closeErr)

fmt.Println(joinedErr)
// Output:
// original error
// close error
```

You can even take it one step further and get rid of the anonymous function by
defining a "joinErrs(...)" that takes a pointer to the original error, like so:

```
func joinErrs(origErr *error, newErr error) {
	*origErr = errors.Join(*origErr, newErr)
}

func example(r io.ReadCloser) (err error) {
	defer joinErrs(&err, r.Close()) // Woho! Only a single line :D

	// ... code that reads from r ...
}
```

Wow! We just saved two (!!) lines of code everytime we need to `defer` a
`(io.ReadCloser).Close()` call.

And here's a working example of this: https://go.dev/play/p/JDE-AJvujJr

## TL;DR

Please set errors from `defer` calls with
[`errors.Join`](https://pkg.go.dev/errors#Join):

```
func example(r io.ReadCloser) (err error) {
	defer func() {
		err = errors.Join(err, r.Close()) // Magic!
	}()

	// ... code that reads from r ...
}

```

Enjoy!
