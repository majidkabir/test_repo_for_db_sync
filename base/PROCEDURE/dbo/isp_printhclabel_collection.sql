SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: isp_PrintHCLabel_Collection                        */
/* Creation Date: 17-Oct-2007                                           */
/* Copyright: IDS                                                       */
/* Written by: TLTing                                                   */
/*                                                                      */
/* Purpose: To print Colection Label for SG Healthcare.                 */
/*                                                                      */
/* Called By: PB - Trade Return & Report Modules                        */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Purposes                                      */
/************************************************************************/

CREATE PROC [dbo].[isp_PrintHCLabel_Collection] (
       @cStorerKey     NVARCHAR(15) = '' , 
       @cReceiptKey    NVARCHAR(10) = '' , 
       @dAddDateStart  datetime = '' , 
       @dAddDateEnd    datetime = '' , 
       @cSector        NVARCHAR(15) = '' , 
       @cPallet        NVARCHAR(15) = '' ,  
       @cCarton        NVARCHAR(15) = '' , 
       @cBag           NVARCHAR(15) = '' , 
       @cPiece         NVARCHAR(15) = '' ,
       @nNoOfPackages  int      = 1  
)
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_continue    int,
           @c_errmsg      NVARCHAR(255),
           @b_success     int,
           @n_err         int, 
           @b_debug       int

   DECLARE @n_cnt int

   DECLARE @t_Result Table (
         StorerKey            NVARCHAR(15),
         ExternReceiptKey     NVARCHAR(20),
         CollectionOrder      NVARCHAR(20),
         MPS                  int,
			EffectiveDate        Datetime,
			CarrierName          NVARCHAR(30),	
			CarrierAddress1      NVARCHAR(45),	
			CarrierAddress2      NVARCHAR(45),	
			CarrierCity          NVARCHAR(45),	
         Remarks              NVARCHAR(100),
         company              NVARCHAR(45),
			address1             NVARCHAR(45),
			address2             NVARCHAR(45),
			phone1               NVARCHAR(18),
			phone2               NVARCHAR(18),
         packages             int,
         Total_packages       int,
         Sector        NVARCHAR(15)  , 
         Pallet        NVARCHAR(15)  ,  
         Carton        NVARCHAR(15)  , 
         Bag           NVARCHAR(15)  , 
         Piece         NVARCHAR(15)  ,  
         rowid                int IDENTITY(1,1)   )


   IF @dAddDateEnd = Convert(datetime, '1/1/1900')
      Set @dAddDateEnd = getdate()

   Set @b_debug= 0

   IF @b_debug = 1
   BEGIN

      SELECT '@cStorerKey' = @cStorerKey, '@cReceiptKey' = @cReceiptKey
      SELECT '@dAddDateStart', @dAddDateStart, '@dAddDateEnd' = @dAddDateEnd 
      SELECT '@cSector' = @cSector, '@cPallet' = @cPallet, '@cCarton' = @cCarton   
      SELECT '@cBag' = @cBag , '@cPiece' = @cPiece, '@nNoOfPackages' = @nNoOfPackages 
   END

   IF @b_debug = 1
   BEGIN
   
      SELECT
      R.StorerKey,
      R.ExternReceiptKey,
      CollectionOrder = CASE WHEN LEN(R.ExternReceiptkey) > 5 THEN Substring(R.ExternReceiptkey, 6, LEN(R.ExternReceiptkey)-5) ELSE '' END,
      MPS = sum(RD.QtyExpected),
      R.EffectiveDate,
      R.CarrierName,	
      R.CarrierAddress1,	
      R.CarrierAddress2,
      R.CarrierCity,	
      Remarks = Convert(NVARCHAR(100),R.Notes),
      Storer.company,
      Storer.address1,
      Storer.address2,
      Storer.phone1,
      Storer.phone2,
      @n_cnt,
      @nNoOfPackages,
      @cSector, 
      @cPallet,  
      @cCarton, 
      @cBag , 
      @cPiece  
      FROM 
      Receipt R (nolock)
         JOIN ReceiptDetail RD (nolock) ON (R.receiptkey = RD.receiptkey)
         JOIN Storer (nolock) ON (Storer.StorerKey = R.StorerKey)
		WHERE ( R.DocType = 'R' )
      AND   ( ISNULL(dbo.fnc_RTrim(@cReceiptKey), '') = '' OR R.ReceiptKey = @cReceiptKey) 
		AND   ( ISNULL(dbo.fnc_RTrim(@cStorerKey), '')  = '' OR R.StorerKey = @cStorerKey )
 		AND   ( ISNULL(dbo.fnc_RTrim(@dAddDateStart), '') = '' OR CONVERT(datetime, convert(char(11), R.AddDate), 103 ) >= @dAddDateStart )
 		AND   ( ISNULL(dbo.fnc_RTrim(@dAddDateEnd), '') = '' OR CONVERT(datetime, convert(char(11), R.AddDate), 103 )  <= @dAddDateEnd )

      GROUP BY
      R.StorerKey,
      R.ExternReceiptKey,
      R.EffectiveDate,
      R.CarrierName,	
      R.CarrierAddress1,	
      R.CarrierAddress2,
      R.CarrierCity,	
      Convert(NVARCHAR(100),R.Notes),
      Storer.company,
      Storer.address1,
      Storer.address2,
      Storer.phone1,
      Storer.phone2



   END

   Set @n_cnt = 1
   While @n_cnt <=  @nNoOfPackages 		
   BEGIN
      INSERT INTO @t_Result (StorerKey,         ExternReceiptKey,         CollectionOrder,
			MPS,                 EffectiveDate,		CarrierName,			
         CarrierAddress1,     CarrierAddress2,  CarrierCity,
         Remarks,
         company,      			address1,			address2,
			phone1,      			phone2,           packages,
         Total_packages,      Sector,           Pallet,  
         Carton,              Bag,              Piece     )

      SELECT
      R.StorerKey,
      R.ExternReceiptKey,
      CollectionOrder = CASE WHEN LEN(R.ExternReceiptkey) > 5 THEN Substring(R.ExternReceiptkey, 6, LEN(R.ExternReceiptkey)-5) ELSE '' END,
      MPS = sum(RD.QtyExpected),
      R.EffectiveDate,
      R.CarrierName,	
      R.CarrierAddress1,	
      R.CarrierAddress2,
      R.CarrierCity,	
      Remarks = Convert(NVARCHAR(100),R.Notes),
      Storer.company,
      Storer.address1,
      Storer.address2,
      Storer.phone1,
      Storer.phone2,
      @n_cnt,
      @nNoOfPackages,
      @cSector, 
      @cPallet,  
      @cCarton, 
      @cBag , 
      @cPiece   
      FROM 
      Receipt R (nolock)
         JOIN ReceiptDetail RD (nolock) ON (R.receiptkey = RD.receiptkey)
         JOIN Storer (nolock) ON (Storer.StorerKey = R.StorerKey)
		WHERE ( R.DocType = 'R' )
      AND   ( ISNULL(dbo.fnc_RTrim(@cReceiptKey), '') = '' OR R.ReceiptKey = @cReceiptKey) 
		AND   ( ISNULL(dbo.fnc_RTrim(@cStorerKey), '')  = '' OR R.StorerKey = @cStorerKey )
 		AND   ( ISNULL(dbo.fnc_RTrim(@dAddDateStart), '') = '' OR CONVERT(datetime, convert(char(11), R.AddDate), 103 ) >= @dAddDateStart )
 		AND   ( ISNULL(dbo.fnc_RTrim(@dAddDateEnd), '') = '' OR CONVERT(datetime, convert(char(11), R.AddDate), 103 )  <= @dAddDateEnd )

      GROUP BY
      R.StorerKey,
      R.ExternReceiptKey,
      R.EffectiveDate,
      R.CarrierName,	
      R.CarrierAddress1,	
      R.CarrierAddress2,
      R.CarrierCity,	
      Convert(NVARCHAR(100),R.Notes),
      Storer.company,
      Storer.address1,
      Storer.address2,
      Storer.phone1,
      Storer.phone2


      Select @n_cnt = @n_cnt + 1
   END

   
Quit:
   SELECT * FROM @t_Result 
   ORDER BY RowID 
END

GO