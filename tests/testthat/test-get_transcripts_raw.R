test_that("get_transcripts_raw returns a named list by default", {
  skip_if_not(
    dir.exists(file.path("data-raw", "transcripts")) ||
      nzchar(system.file("data-raw", "transcripts", package = "bribeR")),
    message = "data-raw/transcripts not available"
  )
  result <- get_transcripts_raw()
  expect_type(result, "list")
  expect_gt(length(result), 0)
  expect_true(all(nzchar(names(result))))
})

test_that("get_transcripts_raw filters by id", {
  skip_if_not(
    dir.exists(file.path("data-raw", "transcripts")) ||
      nzchar(system.file("data-raw", "transcripts", package = "bribeR")),
    message = "data-raw/transcripts not available"
  )
  result <- get_transcripts_raw(id = 2)
  expect_type(result, "list")
  expect_equal(length(result), 1)
  expect_equal(names(result), "2")
})

test_that("get_transcripts_raw combine = TRUE returns a tibble with n column", {
  skip_if_not(
    dir.exists(file.path("data-raw", "transcripts")) ||
      nzchar(system.file("data-raw", "transcripts", package = "bribeR")),
    message = "data-raw/transcripts not available"
  )
  result <- get_transcripts_raw(id = 2, combine = TRUE)
  expect_s3_class(result, "data.frame")
  expect_true("id" %in% names(result))
  expect_true(all(result$id == 2))
})

test_that("get_transcripts_raw errors on non-existent ID", {
  skip_if_not(
    dir.exists(file.path("data-raw", "transcripts")) ||
      nzchar(system.file("data-raw", "transcripts", package = "bribeR")),
    message = "data-raw/transcripts not available"
  )
  expect_error(
    get_transcripts_raw(id = 99999),
    "No matching transcripts"
  )
})



