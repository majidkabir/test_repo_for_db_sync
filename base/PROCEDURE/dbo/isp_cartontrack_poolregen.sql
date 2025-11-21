SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Stored Proc : isp_CartonTrack_PoolReGen                               */
/* Creation Date: 29 June 2015                                          */
/* Copyright: IDS                                                       */
/* Written by: TLTING                                                   */
/*                                                                      */
/* Purpose: to insert TrackingNo from CartonTrack_Pool                  */
/*                                                                      */
/* Input Parameters: NONE                                               */
/*                                                                      */
/* Output Parameters: NONE                                              */
/*                                                                      */
/* Return Status: NONE                                                  */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By:   Backend Job                                             */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 21Aug2015    TLTING        sort by RowRef                            */
/* 14Jan2016    NJOW01        360602-cater for Korea check digit formula*/
/* 19Feb2016    TLTING        Loop cater on over range setup            */
/* 10Jan2017    TLTING        WMS-695 CT setup grouping                 */
/* 25Apr2017    TLTING        Bug fix - CTgroup filtering               */
/* 23Mar2021    TLTING01 1.1  New checkdigit method                     */
/* 03Jul2023    TLTING02 1.2  New checkdigit method - 4                 */
/************************************************************************/
CREATE   PROCEDURE [dbo].[isp_CartonTrack_PoolReGen] ( @c_CTgroup  Nvarchar(10) = '%', @c_CheckDigitType NCHAR(1) = '')
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   declare @c_CarrierName Nvarchar(30), @c_KeyName Nvarchar(30), @c_FromCartonTrack Nvarchar(20), @c_ToCartonTrack Nvarchar(20)
   DECLARE @c_ReOrderLevel Nvarchar(20), @c_Shipperkey Nvarchar(30), @c_TrackingNumber Nvarchar(30)
   DECLARE @n_FROMCartonTrack BIGINT, @n_ToCartonTrack BIGINT  , @n_ReOrderLevel BIGINT, @n_LastCartonTrack BIGINT
   DECLARE @n_CntCartonTrack BIGINT, @n_TrackingNumber BIGINT
   DECLARE @n_err INT, @n_cnt int
   DECLARE @c_SQL NVARCHAR(2000), @n_debug int
   DECLARE @n_SumDigit INT = 0   -- TLTING01
   DECLARE @n_CheckNumber BIGINT = 0

  SET @n_debug = 0
   --IF OBJECT_ID('tempdb..#TrackingNo') IS NOT NULL
   --   DROP TABLE #TrackingNo

	SET @n_FROMCartonTrack= 0
	SET @n_ToCartonTrack= 0
	SET @n_ReOrderLevel= 0
	SET @n_LastCartonTrack= 0
	SET @n_CntCartonTrack= 0
	SET @n_TrackingNumber= 0

   --CREATE TABLE #TrackingNo
   --(  TrackingNo NVARCHAR(20) PRIMARY key)

   IF EXISTS (
   SELECT 1 FROM codelkup (NOLOCK)
   WHERE LISTNAME = 'CartnTrack'      )
   Begin

      IF @c_CTgroup = '%'
      BEGIN
         DECLARE Item_Cur CURSOR LOCAL FAST_FORWARD READ_ONLY  FOR
            SELECT Code, Code2, UDF02, UDF03 , UDF04
            FROM codelkup (NOLOCK)
            WHERE LISTNAME = 'CartnTrack'
      END
      ELSE
      BEGIN
         DECLARE Item_Cur CURSOR LOCAL FAST_FORWARD READ_ONLY  FOR
            SELECT Code, Code2, UDF02, UDF03 , UDF04
            FROM codelkup (NOLOCK)
            WHERE LISTNAME = 'CartnTrack'
            and Notes2 = @c_CTgroup
      END

    OPEN Item_Cur
    FETCH NEXT FROM Item_Cur INTO @c_CarrierName ,@c_KeyName, @c_FromCartonTrack, @c_ToCartonTrack, @c_ReOrderLevel
    --@c_Shipperkey, @c_KeyName, @c_FromCartonTrack, @c_ToCartonTrack, @c_ReOrderLevel, @c_CarrierName
    WHILE @@FETCH_STATUS = 0
    BEGIN

       IF @n_debug = '1'
       BEGIN
          PRINT '@c_CarrierName- ' + @c_CarrierName + ' ,@c_KeyName-' + @c_KeyName + ' ,@c_Min#-' + @c_FromCartonTrack +
                ' ,@c_Max#- ' + @c_ToCartonTrack  + ' ,@c_ReOrderLevel- ' + @c_ReOrderLevel
       END

       SET  @n_FROMCartonTrack = ISNULL(CAST (@c_FromCartonTrack AS BIGINT) , 0)
       SET  @n_ToCartonTrack = ISNULL(CAST (@c_ToCartonTrack AS BIGINT) , 0)

       SET  @n_ReOrderLevel = ISNULL(CAST (@c_ReOrderLevel AS BIGINT) , 0)
       SET @n_LastCartonTrack = 0
       SET @n_CntCartonTrack = 0
       SET @n_TrackingNumber = 0

      -- last carton track # from pool.
      -- remove check digit , 11 digit needed

      IF ISNULL(@c_CheckDigitType,'') = '4' -- TLTING02
      BEGIN
         SELECT  TOP 1  @n_LastCartonTrack = CAST(( CONVERT(NVARCHAR(9), TrackingNo))  AS BIGINT) -- CONVERT(BIGINT, ( LEFT(11,  TrackingNo) ) )
         FROM dbo.CartonTrack_Pool  (NOLOCK)
         Where CarrierName    = @c_CarrierName
         AND   KeyName        = @c_KeyName
         ORDER BY RowRef desc
      END
      ELSE
      BEGIN
         SELECT  TOP 1  @n_LastCartonTrack = CAST(( CONVERT(NVARCHAR(11), TrackingNo))  AS BIGINT) -- CONVERT(BIGINT, ( LEFT(11,  TrackingNo) ) )
         FROM dbo.CartonTrack_Pool  (NOLOCK)
         Where CarrierName    = @c_CarrierName
         AND   KeyName        = @c_KeyName
         ORDER BY RowRef desc
      END

      SELECT   @n_CntCartonTrack = SUM(1)
      FROM dbo.CartonTrack_Pool WITH (NOLOCK)
      Where CarrierName    = @c_CarrierName
      AND   KeyName        = @c_KeyName

      IF @n_LastCartonTrack  IS NULL
         SET @n_LastCartonTrack = 0

      SET @n_TrackingNumber = @n_LastCartonTrack

      IF @n_CntCartonTrack  IS NULL
        SET @n_CntCartonTrack = 0

      IF @n_TrackingNumber = 0
	  BEGIN
         SET @n_TrackingNumber = @n_FROMCartonTrack
      END
	  ELSE
	  BEGIN
		SET @n_TrackingNumber = @n_TrackingNumber + 1  -- running number run
	  END

      IF  @n_CntCartonTrack < @n_ReOrderLevel
      BEGIN
       IF @n_debug = '1'
       BEGIN
          PRINT 'START '
       END


       IF @n_debug = '1'
       BEGIN
          PRINT 'Start TrackingNumber - ' + CAST(@n_TrackingNumber AS NVARCHAR) + ' ,@n_ToCartonTrack - ' + CAST(@n_ToCartonTrack AS NVARCHAR) +
           + ' ,CheckdigitFlag - ' + @c_CheckDigitType
          Print ' @n_CntCartonTrack- ' + CAST (@n_CntCartonTrack AS NVARCHAR)  + ' , @n_ReOrderLevel-' + CAST (@n_ReOrderLevel AS NVARCHAR)
       END


         WHILE   @n_CntCartonTrack < @n_ReOrderLevel
         BEGIN

            IF @n_TrackingNumber > @n_ToCartonTrack
            BEGIN
               SET @n_TrackingNumber = @n_FROMCartonTrack
            END

            -- tracking number - 11 digit running number + check digit ( 99999999999 % 7 )
            IF ISNULL(@c_CheckDigitType,'') = '1'
            BEGIN
            	 --NJOW01
               SET @c_TrackingNumber = CONVERT( NVARCHAR(11), @n_TrackingNumber) + CONVERT(NCHAR(1), (CAST(SUBSTRING(LTRIM(CONVERT(NVARCHAR(11), @n_TrackingNumber)),3,9) AS BIGINT) % 7))
            END
            ELSE IF ISNULL(@c_CheckDigitType,'') = '2'
            BEGIN
               SET @c_TrackingNumber = CONVERT( NVARCHAR(11), @n_TrackingNumber) + CONVERT(NCHAR(1), (@n_TrackingNumber % 7))
            END
            ELSE IF ISNULL(@c_CheckDigitType,'') = '3'  -- TLTING01
            BEGIN
               -- 30001210999 , SET 3+0+0+0+1+2+1+0+9+9+9 = 34
               -- Check digit - 34 % 7 = 6

               SET @n_CheckNumber = @n_TrackingNumber
               SET @n_SumDigit = 0
               WHILE @n_CheckNumber > 0
               BEGIN
                  SET @n_SumDigit  = @n_SumDigit + @n_CheckNumber % 10
                  SET @n_CheckNumber =  @n_CheckNumber / 10
               END

               SET @c_TrackingNumber = CONVERT( NVARCHAR(11), @n_TrackingNumber) + CONVERT(NCHAR(1), (@n_SumDigit % 7))

            END
            ELSE IF ISNULL(@c_CheckDigitType,'') = '4'  -- TLTING02
            BEGIN
               -- 300012109 , SET 3+0+0+0+1+2+1+0+9 = 16
               -- Check digit - 16 % 7 = 2

               SET @n_CheckNumber = @n_TrackingNumber
               SET @n_SumDigit = 0
               WHILE @n_CheckNumber > 0
               BEGIN
                  SET @n_SumDigit  = @n_SumDigit + @n_CheckNumber % 10
                  SET @n_CheckNumber =  @n_CheckNumber / 10
               END

               SET @c_TrackingNumber = CONVERT( NVARCHAR(9), @n_TrackingNumber) + CONVERT(NCHAR(1), (@n_SumDigit % 7))

            END
            ELSE
            BEGIN
               Break
            END

             IF @n_debug = '1'
             BEGIN
                 Print ' New @c_TrackingNumber - ' + CAST (@c_TrackingNumber AS NVARCHAR)
             END

            IF EXISTS ( SELECT 1 FROM dbo.CartonTrack_Pool (NOLOCK)
                              Where CarrierName    = @c_CarrierName
                              AND   KeyName        = @c_KeyName  AND  TrackingNo = @c_TrackingNumber )
            BEGIN
               PRINT 'Tracking Number over run!!! '
               Break
            END
            ELSE
            BEGIN
               BEGIN TRAN

               INSERT INTO dbo.CartonTrack_Pool ( TrackingNo,CarrierName,KeyName,LabelNo,CarrierRef1,CarrierRef2  )
               VALUES ( @c_TrackingNumber, @c_CarrierName, @c_KeyName,'','',''   )

               IF @@ROWCOUNT = 0 AND @@ERROR <> 0
               BEGIN
                  ROLLBACK TRANSACTION
                  Break
               END
               ELSE
               BEGIN
                  COMMIT TRAN
               END
            END

            SET @n_CntCartonTrack = @n_CntCartonTrack  + 1   -- loop number of pool replenishmnet
			   SET @n_TrackingNumber = @n_TrackingNumber + 1  -- running number run
         END

      END

     FETCH NEXT FROM Item_Cur INTO @c_CarrierName ,@c_KeyName, @c_FromCartonTrack, @c_ToCartonTrack, @c_ReOrderLevel
    END
    CLOSE Item_Cur
    DEALLOCATE Item_Cur
   End
   Else
   Begin
    print 'NO cartontrack setup : No Problem'
   End

 END


GO