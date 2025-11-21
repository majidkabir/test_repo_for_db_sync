SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/
/* Store Procedure:  isp_RdsGenUPC                                            */
/* Creation Date:  01-Aug-2008                                                */
/* Copyright: IDS                                                             */
/* Written by:  Wan (Aquasora)                                                */
/*                                                                            */
/* Purpose:  Post RDS Orders to WMS Orders Table                              */
/*                                                                            */
/* Input Parameters:                                                          */
/*                                                                            */
/* Output Parameters:  None                                                   */
/*                                                                            */
/* Return Status:  None                                                       */
/*                                                                            */
/* Usage:                                                                     */
/*                                                                            */
/* Local Variables:                                                           */
/*                                                                            */
/* Called By:  RDS Application                                                */
/*                                                                            */
/* PVCS Version: 1.1                                                          */
/*                                                                            */
/* Version: 5.4                                                               */
/*                                                                            */
/* Data Modifications:                                                        */
/*                                                                            */
/* Updates:                                                                   */
/* Date         Author     Ver   Purposes                                     */
/* 30-Nov-2010  Local IT   1.1   SOS# 197592 - Bug fix                        */
/******************************************************************************/

CREATE PROC [dbo].[isp_RdsGenUPC] (
   @c_storerkey  NVARCHAR(15),
   @c_style      NVARCHAR(20),
   @b_Success    int OUTPUT,
   @n_err        int OUTPUT,
   @c_errmsg     NVARCHAR(215) OUTPUT)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_seqno         NVARCHAR(10),
           @c_color         NVARCHAR(10),
           @c_size          NVARCHAR(10),
           @c_measurement   NVARCHAR(10),
           @c_upc           NVARCHAR(30),
           @c_Reverseupc    NVARCHAR(20),
           @c_checkdigit    NVARCHAR(1),
           @n_Continue      int,
           @n_StartTCnt     int,
           @n_found         int,
           @b_loop          int,
           @n_minseq        int,
           @n_maxseq        int,
           @n_upcseq        int,
           @n_cnt           int,
           @n_oddpos        int,
           @n_evenpos       int,
           @n_sumodd        int,
           @n_sumeven       int,
           @n_multipleoften int,
           @b_getmax        int,
           @b_debug         int

   SET @n_StartTCnt=@@TRANCOUNT
   SET @n_Continue=1
   SET @b_debug = 0

   CREATE TABLE [#UPCSeq]
  ( storerkey [varchar] (10) NULL,
    seqno     [int]          NOT NULL )

   BEGIN TRAN

   DECLARE csr_stylecolor CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT Color
      FROM rdsStyleColor WITH (NOLOCK)
      WHERE Storerkey = @c_storerkey
      AND   Style     = @c_style

   OPEN csr_stylecolor

   SET @n_minseq = 0
   -- 2008-07-03 Change Request to UPC generation:- Last 6 digit of Storer, 5 digit sequential, Check digit
   -- SET @n_maxseq = 999999
   SET @n_maxseq = 99999
   SET @b_getmax = 1

   FETCH NEXT FROM csr_stylecolor INTO  @c_color

   WHILE @@FETCH_STATUS <> -1
   BEGIN
      DECLARE csr_stylecolorsize CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT DISTINCT Sizes, Measurement
         FROM rdsStyleColorSize WITH (NOLOCK)
         WHERE Storerkey = @c_storerkey
         AND   Style     = @c_style

      OPEN csr_stylecolorsize

      FETCH NEXT FROM csr_stylecolorsize INTO  @c_size, @c_measurement
      WHILE @@FETCH_STATUS <> -1
         BEGIN

            IF @b_debug = 1
            BEGIN
               SELECT @c_style '@c_style', @c_size '@c_size', @c_color '@c_color', @c_Measurement '@c_Measurement', @c_storerkey '@c_storerkey'
            END

            SET @n_found = 0
            SET @c_upc   = ''

            SELECT @n_found = 1,    @c_seqno = seqno, @c_upc = UPC
            FROM  rdsStyleColorSize WITH (NOLOCK)
            WHERE Storerkey = @c_storerkey
            AND   Style     = @c_style
            AND   Color     = @c_color
            AND   Sizes     = @c_size
            -- AND   Measurement = @c_Measurement

            IF @n_found = 0
            BEGIN
               -- Get RDSStyleColorSize SeqNo
               SELECT @c_seqno = RIGHT('00000'+ CAST( CAST(ISNULL(MAX(SeqNo), '00000') AS int)+ 1 AS NVARCHAR(10)),5)
               FROM rdsStyleColorSize WITH (NOLOCK)
               WHERE Storerkey = @c_storerkey
               AND   Style     = @c_style
               AND   Color     = @c_color

               IF @b_debug = 1
               BEGIN
                  SELECT @n_found '@n_found', @c_size '@c_size', @c_Measurement '@c_Measurement', @c_seqno '@c_seqno'
               END
            END

            -- 2008-07-03 Change Request to UPC generation:- Last 6 digit of Storer, 5 digit sequential, Check digit
            -- IF RTRIM(ISNULL(@c_upc,'')) = '' -- Commented by Ricky to Trim first then Check Null
            IF ISNULL(RTRIM(@c_upc),'') = ''
            BEGIN
               ---- Get UPC SeqNo
              DELETE FROM #UPCSeq

               INSERT INTO #UPCSeq
               --SELECT Storerkey, CAST(SUBSTRING(SKU,6,6) AS int)
               SELECT Storerkey, CAST(SUBSTRING(SKU,7,5) AS int)
               FROM SKU WITH (NOLOCK)
               WHERE STORERKEY   = @c_storerkey
               AND   LEFT(SKU,6) = RIGHT(@c_storerkey,6)
               --  AND LEFT(SKU,5) = RIGHT(@c_storerkey,5)

               --SELECT Storerkey, CAST(SUBSTRING(UPC,6,6) AS int)
               INSERT INTO #UPCSeq
               SELECT Storerkey, CAST(SUBSTRING(UPC,7,5) AS int)
               FROM RdsStyleColorSize WITH (NOLOCK)
               WHERE STORERKEY   = @c_storerkey
               AND   LEFT(UPC,6) = RIGHT(@c_storerkey,6)
               AND   ISNULL(RTRIM(UPC), '') <> ''
               --  AND LEFT(UPC,5) = RIGHT(@c_storerkey,5)

               IF @n_minseq = 0
               BEGIN
                  SELECT @n_minseq = MIN(SeqNo)
                  FROM #UPCSeq
                  WHERE SeqNo < @n_maxseq And SeqNo > 0 -- SOS# 197592

                  IF @n_minseq <> 1
                  BEGIN
                     SET @n_upcseq = 0
                     SET @b_getmax = 0
                  END
               END

               IF @n_upcseq <> 0
               BEGIN
                  SET @b_loop = 1
                  IF (@n_minseq + 1 >= @n_maxseq) --OR (@n_upcseq = 0)
                     -- SET @n_upcseq = 999999
                     SET @n_upcseq = 99999
                  ELSE
                     SET @n_upcseq = @n_maxseq

                  SET @n_cnt = 0
                  WHILE @b_loop = 1
                  BEGIN

                     SELECT @n_upcseq = MAX(SeqNo) , @n_cnt = COUNT(DISTINCT SeqNo)
                     FROM #UPCSeq
                     WHERE SeqNo > @n_minseq
                       AND SeqNo < @n_upcseq
                  --   GROUP BY SeqNo
                  --   ORDER BY SeqNo

                     IF (@n_upcseq-@n_minseq = @n_cnt) OR (@n_cnt = 0)
                    -- IF (@n_maxseq-@n_upcseq = 1) OR (@n_cnt = 0)
                     BEGIN
                        IF @n_cnt = 0
                           SET @n_upcseq = @n_minseq
                        SET @b_loop = 0
                     END
                     SET @n_maxseq = @n_upcseq
                  END
               END

               SET @n_upcseq = @n_upcseq + 1
               SET @c_upc = ''
               --SET @c_upc = RIGHT(@c_storerkey,5) + RIGHT('000000'+CAST(@n_upcseq AS NVARCHAR(6)),6)
               SET @c_upc = RIGHT(@c_storerkey,6) + RIGHT('00000'+CAST(@n_upcseq AS NVARCHAR(5)),5)
               SET @n_minseq = @n_upcseq

               -- Calculate CheckDigit
               SET @n_oddpos  = 1
               SET @n_evenpos = 2
               SET @n_sumodd  = 0
               SET @n_sumeven = 0
               SET @n_multipleoften = 0

               SET @c_Reverseupc = REVERSE(@c_upc)

               WHILE LEN(@c_Reverseupc) >= @n_oddpos
               BEGIN
                  -- Odd

                  IF @n_oddpos <= LEN(@c_Reverseupc)
                     SET @n_sumodd  = @n_sumodd  + (SUBSTRING(@c_Reverseupc,@n_oddpos,1)  * 3)
                  -- Even
                  IF @n_evenpos <= LEN(@c_Reverseupc)
                     SET @n_sumeven = @n_sumeven + (SUBSTRING(@c_Reverseupc,@n_evenpos,1) * 1)

                  SET @n_oddpos  = @n_oddpos  + 2
                  SET @n_evenpos = @n_evenpos + 2
               END

               SET @n_multipleoften =  CEILING(CAST(@n_sumodd + @n_sumeven AS Decimal(10,3))/10) * 10

               SET @c_checkdigit = CAST ((@n_multipleoften - (@n_sumodd + @n_sumeven))AS NVARCHAR(1))

               SET @c_upc = @c_upc + @c_checkdigit

               IF @n_found = 0
               BEGIN
                  INSERT INTO rdsStyleColorSize (SeqNo, Storerkey, Style, Color, Sizes, Measurement, UPC)
                  VALUES (@c_seqno, @c_storerkey, @c_style, @c_color, @c_size, @c_measurement, @c_upc)
               END
               ELSE
               BEGIN
                  UPDATE rdsStyleColorSize
                  SET    UPC = @c_upc
                  WHERE  SeqNo     = @c_seqno
                  AND    Storerkey = @c_storerkey
                  AND    Style     = @c_style
                  AND    Color     = @c_color
                  AND    Sizes     = @c_size
               END

               SET @n_Err = @@ERROR
               IF @n_Err <> 0
               BEGIN
                  SET @n_Continue = 3
                  SET @b_success = -1
                  SET @c_ErrMsg = 'Insert RDSStyleColorSize Failed!'
                  GOTO QUIT
               END

            END
            FETCH NEXT FROM csr_stylecolorsize INTO  @c_size, @c_measurement
         END -- While csr_stylecolorsize cursor loop
         CLOSE csr_stylecolorsize
         DEALLOCATE csr_stylecolorsize

      FETCH NEXT FROM csr_stylecolor INTO  @c_color
   END -- While csr_stylecolor cursor loop
   CLOSE csr_stylecolor
   DEALLOCATE csr_stylecolor

   DROP TABLE [#UPCSeq]

QUIT:
   IF @n_continue = 3  -- Error Occured - Process And Return
   BEGIN
      SELECT @b_success = 0

      IF @@TRANCOUNT = 1 OR @@TRANCOUNT >= @n_starttcnt
      BEGIN
         ROLLBACK TRAN
      END
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_RdsGenUPC'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      SELECT @b_success = 1
      WHILE @@TRANCOUNT > @n_starttcnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END
END -- Procedure

GO