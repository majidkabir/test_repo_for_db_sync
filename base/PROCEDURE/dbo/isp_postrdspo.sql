SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure:  isp_PostRdsPO                                      */
/* Creation Date:  01-Aug-2008                                          */
/* Copyright: IDS                                                       */
/* Written by:  Wan (Aquasora)                                          */
/*                                                                      */
/* Purpose:  Post RDS Orders to WMS Orders Table                        */
/*                                                                      */
/* Input Parameters:  @n_RdsPONo                                        */
/*                                                                      */
/* Output Parameters:  None                                             */
/*                                                                      */
/* Return Status:  None                                                 */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By:  RDS Application                                          */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver.  Purposes                                  */
/* 14-Sep-2009  NJOW01  1.2   SOS#147418 Add userdefind03 as container# */          
/*                            and duplicate checking include container# */
/* 29-May-2014  TKLIM   1.3   Added Lottables 06-15                     */
/************************************************************************/
CREATE PROC [dbo].[isp_PostRdsPO] (
   @n_RdsPONo    int, 
   @c_POKey      NVARCHAR(10) OUTPUT,
   @c_Status     NVARCHAR(10) OUTPUT,
   @b_Success    int OUTPUT,
   @n_err        int OUTPUT,
   @c_errmsg     NVARCHAR(215) OUTPUT)
AS 
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF


   DECLARE @c_rdsPOLineNo     NVARCHAR(10), 
           @c_Lottable01      NVARCHAR(18), 
           @c_Lottable02      NVARCHAR(18), 
           @c_Lottable03      NVARCHAR(18),
           @d_Lottable04      DATETIME,
           @d_Lottable05      DATETIME,
           @c_Lottable06      NVARCHAR(30),
           @c_Lottable07      NVARCHAR(30),
           @c_Lottable08      NVARCHAR(30),
           @c_Lottable09      NVARCHAR(30),
           @c_Lottable10      NVARCHAR(30),
           @c_Lottable11      NVARCHAR(30),
           @c_Lottable12      NVARCHAR(30),
           @d_Lottable13      DATETIME,
           @d_Lottable14      DATETIME,
           @d_Lottable15      DATETIME,
           @c_ExternPOKey     NVARCHAR(20),
           @c_StorerKey       NVARCHAR(15),
           @c_LoadKey         NVARCHAR(10),
           @c_SKU             NVARCHAR(20),
           @c_skudescription  NVARCHAR(60),
           @n_Qty             int,
           @n_unitprice       FLOAT,
           @n_POLineNumber    int,
           @c_POLineNumber    NVARCHAR(5),
           @c_PackUOM3        NVARCHAR(10),
           @c_PackKey         NVARCHAR(10),
           @n_Continue        int, 
           @n_StartTCnt       int,            
           @c_BuyerPO         NVARCHAR(20), 
           @c_userdefine01    NVARCHAR(10),
           @c_Facility        NVARCHAR(10),
           @c_userdefine03    NVARCHAR(30) --NJOW01

   SET @n_StartTCnt=@@TRANCOUNT 
   SET @n_Continue=1 

   BEGIN TRAN 

   SET @c_POKey = ''
   SELECT @c_POKey       = POKey, 
          @c_ExternPOKey = ExternPOKey,
          @c_StorerKey   = StorerKey,
          @c_userdefine01= UserDefine01, 
          @c_Facility    = PlaceOfDelivery,    
          @c_userdefine03= UserDefine03 --NJOW01
   FROM rdsPO WITH (NOLOCK) 
   WHERE rdsPONo = @n_RdsPONo 


   IF ISNULL( dbo.fnc_RTrim(@c_POKey), '') = ''
   BEGIN
      SELECT @c_POKey  = POKey
      FROM   PO WITH (NOLOCK)
      WHERE  StorerKey = @c_StorerKey
      AND    ExternPOKey = @c_ExternPOKey 
      AND    (STATUS NOT IN ('9','99') OR EXTERNSTATUS NOT IN ('9','99'))
      AND    Userdefine03 = @c_userdefine03 --NJOW01
   END


   IF ISNULL( dbo.fnc_RTrim(@c_POKey), '') <> ''
   BEGIN 

      IF EXISTS(SELECT 1 FROM ReceiptDetail WITH (NOLOCK) WHERE POKey = @c_POKey )
      BEGIN 
         -- Ricky Yee on Sept 4th, Removed the Update of the RDSPO
         -- and change the error message

         /* SET @c_status = '9'

         UPDATE RDSPO SET Status = @c_status
         WHERE RdsPONo = @n_RdsPONo

         SET @n_Err = @@ERROR
         IF @n_Err <> 0 
         BEGIN
            SET @n_Continue = 3
            SET @b_success = -1
            SET @c_ErrMsg = 'Update RDSPO Failed!'
            GOTO QUIT
         END

         COMMIT TRAN
         
         SET @b_Success = -1
         SET @n_err = 60001
         SET @c_errmsg = 'PO # :' + dbo.fnc_RTrim(@c_ExternPOKey) + ' Already Processed/Cancel. No Update Allow'
         GOTO QUIT */

         SET @n_Continue = 3
         SET @b_success = -1
         SET @c_ErrMsg = 'The PO# is In-Process for Receiving!'
         GOTO QUIT
      END
      ELSE IF EXISTS(SELECT 1 FROM PO WITH (NOLOCK) WHERE POKey = @c_POKey )
      BEGIN
         DELETE PO 
         WHERE  POKey = @c_POKey
         SET @n_Err = @@ERROR
         IF @n_Err <> 0 
         BEGIN
            SET @n_Continue = 3
            SET @b_success = -1
            SET @c_ErrMsg = 'Duplicate PO#, Delete PO Failed!'  -- Ricky Yee on Sept 4th, Change the Message
            GOTO QUIT
         END
      END 
   END 

   IF ISNULL( dbo.fnc_RTrim(@c_POKey), '') = '' 
   BEGIN
      -- get Next Order Number from nCounter
      SET @b_success = 1

      EXECUTE dbo.nspg_getkey 
          'PO' , 
           10 , 
           @c_POKey OUTPUT , 
           @b_success  OUTPUT, 
           @n_err      OUTPUT, 
           @c_errmsg   OUTPUT 

   END

   IF NOT EXISTS(SELECT 1 FROM PO WITH (NOLOCK) WHERE POKey = @c_POKey)
   BEGIN 
      -- This isDeliveryDate New PO
      INSERT INTO [PO]
            ([POKey]              ,[StorerKey]           ,[ExternPOKey]
            ,[PoGroup]            ,[PODate]              ,[SellersReference]
            ,[BuyersReference]    ,[OtherReference]      ,[POType]
            ,[SellerName]         ,[SellerAddress1]      ,[SellerAddress2]
            ,[SellerAddress3]     ,[SellerAddress4]      ,[SellerCity]
            ,[SellerState]        ,[SellerZip]           ,[SellerPhone]
            ,[SellerVat]          ,[BuyerName]           ,[BuyerAddress1]
            ,[BuyerAddress2]      ,[BuyerAddress3]       ,[BuyerAddress4]
            ,[BuyerCity]          ,[BuyerState]          ,[BuyerZip]
            ,[BuyerPhone]         ,[BuyerVat]            ,[OriginCountry]
            ,[DestinationCountry] ,[Vessel]              ,[VesselDate]
            ,[PlaceOfLoading]     ,[PlaceOfDischarge]    ,[PlaceofDelivery]
            ,[IncoTerms]          ,[Pmtterm]             ,[TransMethod]
            ,[TermsNote]          ,[Signatory]           ,[PlaceofIssue]
            ,[openqty]            ,[Status]              ,[Notes]
            ,[EffectiveDate]      ,[ExternStatus]        ,[LoadingDate]
            ,[ReasonCode]         ,[UserDefine01]        ,[UserDefine02]
            ,[UserDefine03]       ,[UserDefine04]        ,[UserDefine05]
            ,[UserDefine06]       ,[UserDefine07]        ,[UserDefine08]
            ,[UserDefine09]       ,[UserDefine10]        ,[xdockpokey])
      SELECT  @c_POKey            ,[StorerKey]           ,[ExternPOKey]
            ,[PoGroup]            ,[PODate]              ,[SellersReference]
            ,[BuyersReference]    ,[OtherReference]      ,[POType]
            ,[SellerName]         ,[SellerAddress1]      ,[SellerAddress2]
            ,[SellerAddress3]     ,[SellerAddress4]      ,[SellerCity]
            ,[SellerState]        ,[SellerZip]           ,[SellerPhone]
            ,[SellerVat]          ,[BuyerName]           ,[BuyerAddress1]
            ,[BuyerAddress2]      ,[BuyerAddress3]       ,[BuyerAddress4]
            ,[BuyerCity]          ,[BuyerState]          ,[BuyerZip]
            ,[BuyerPhone]         ,[BuyerVat]            ,[OriginCountry]
            ,[DestinationCountry] ,[Vessel]              ,[VesselDate]
            ,[PlaceOfLoading]     ,[PlaceOfDischarge]    ,[PlaceofDelivery]
            ,[IncoTerms]          ,[Pmtterm]             ,[TransMethod]
            ,[TermsNote]          ,[Signatory]           ,[PlaceofIssue]
            ,0                    ,[Status]              ,[Notes]
            ,[EffectiveDate]      ,[ExternStatus]        ,[LoadingDate]
            ,[ReasonCode]         ,[UserDefine01]        ,[UserDefine02]
            ,[UserDefine03]       ,[UserDefine04]        ,[UserDefine05]
            ,[UserDefine06]       ,[UserDefine07]        ,[UserDefine08]
            ,[UserDefine09]       ,[UserDefine10]        ,[xdockpokey]
      FROM rdsPO WITH (NOLOCK)
      WHERE rdsPONo = @n_RdsPONo 

      SET @n_Err = @@ERROR
      IF @n_Err <> 0 
      BEGIN
         SET @n_Continue = 3
         SET @b_success = -1
         SET @c_ErrMsg = 'Insert PO Failed!'
         GOTO QUIT
      END
      ELSE
      BEGIN
         UPDATE rdsPO
            SET POKey = @c_POKey 
         WHERE rdsPONo = @n_RdsPONo 
         SET @n_Err = @@ERROR
         IF @n_Err <> 0 
         BEGIN
            SET @n_Continue = 3
            SET @b_success = -1
            SET @c_ErrMsg = 'UPDATE rdsPO Failed!'
            GOTO QUIT
         END
      END 
      
      SET @n_POLineNumber = 0 

      DECLARE Csr_InsertPODetail CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT rdsPOLineNo, Lottable01, Lottable02, Lottable03, Lottable04, Lottable05,
                             Lottable06, Lottable07, Lottable08, Lottable09, Lottable10,
                             Lottable11, Lottable12, Lottable13, Lottable14, Lottable15
   
         FROM rdsPODetail WITH (NOLOCK)
         WHERE rdsPONo = @n_RdsPONo 

      OPEN Csr_InsertPODetail 
      
      FETCH NEXT FROM Csr_InsertPODetail INTO 
         @c_rdsPOLineNo, @c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04, @d_Lottable05,
                         @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10,
                         @c_Lottable11, @c_Lottable12, @d_Lottable13, @d_Lottable14, @d_Lottable15
 
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         DECLARE Csr_InsertPODetailSize CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
            SELECT SKU, Qty, UnitPrice 
            FROM   rdsPODetailSize WITH (NOLOCK) 
            WHERE  rdsPONo = @n_RdsPONo 
            AND    rdsPOLineNo = @c_rdsPOLineNo 
            AND    Qty > 0 
            
         OPEN Csr_InsertPODetailSize

         FETCH NEXT FROM Csr_InsertPODetailSize INTO
            @c_SKU, @n_Qty, @n_unitprice 

       WHILE @@FETCH_STATUS <> -1
         BEGIN
            SELECT @n_POLineNumber = @n_POLineNumber + 1
            SELECT @c_POLineNumber = RIGHT(REPLICATE ('0', 5) + dbo.fnc_RTrim(Convert(char(5), @n_POLineNumber ) ) , 5)

            SELECT @c_PackUOM3 = PACK.PackUOM3,
                   @c_PackKey  = PACK.PackKey,
                   @c_skudescription = SKU.DESCR 
            FROM   SKU WITH (NOLOCK)
            JOIN   PACK WITH (NOLOCK) ON SKU.PackKey = PACK.PackKey 
            WHERE  SKU.StorerKey = @c_StorerKey
            AND    SKU.SKU = @c_SKU 

            IF ISNULL(dbo.fnc_RTrim(@c_userdefine01), '') <> '' 
               SET @c_Lottable01 = @c_userdefine01

            INSERT INTO PODETAIL 
                  (  POKey,         POLineNumber,        ExternPOKey,      ExternLineNo,
                     Sku,           Skudescription,      StorerKey,        QtyOrdered,
                     UOM,           PackKey,             UnitPrice,        Facility,
                     Lottable01,    Lottable02,          Lottable03,       Lottable04,       Lottable05,
                     Lottable06,    Lottable07,          Lottable08,       Lottable09,       Lottable10,
                     Lottable11,    Lottable12,          Lottable13,       Lottable14,       Lottable15)  
            VALUES ( @c_POKey,      @c_POLineNumber,     @c_ExternPOKey,   @c_rdsPOLineNo,
                     @c_SKU,        @c_skudescription,   @c_Storerkey,     @n_Qty,
                     @c_PackUOM3,   @c_PackKey,          @n_UnitPrice,     @c_Facility,
                     @c_Lottable01, @c_Lottable02,       @c_Lottable03,    @d_Lottable04,    @d_Lottable05,     
                     @c_Lottable06, @c_Lottable07,       @c_Lottable08,    @c_Lottable09,    @c_Lottable10,
                     @c_Lottable11, @c_Lottable12,       @d_Lottable13,    @d_Lottable14,    @d_Lottable15)
                    
            SET @n_Err = @@ERROR
            IF @n_Err <> 0 
            BEGIN
               SET @n_Continue = 3
               SET @b_success = -1
               SET @c_ErrMsg = 'Insert PODETAIL Failed!'
               GOTO QUIT
            END

            FETCH NEXT FROM Csr_InsertPODetailSize INTO
               @c_SKU, @n_Qty, @n_unitprice  
         END 
         CLOSE Csr_InsertPODetailSize 
         DEALLOCATE Csr_InsertPODetailSize

         FETCH NEXT FROM Csr_InsertPODetail into 
            @c_rdsPOLineNo, @c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04, @d_Lottable05,
                            @c_Lottable06, @c_Lottable07, @c_Lottable08, @c_Lottable09, @c_Lottable10,
                            @c_Lottable11, @c_Lottable12, @d_Lottable13, @d_Lottable14, @d_Lottable15
      END -- While Csr_InsertPODetail cursor loop
      CLOSE Csr_InsertPODetail
      DEALLOCATE Csr_InsertPODetail
   END -- If b_success = 1  

QUIT:
   IF @n_continue = 3  -- Error Occured - Process And Return
   BEGIN
      SELECT @b_success = 0

      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_starttcnt
      BEGIN
         ROLLBACK TRAN
      END
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_PostRdsPO'
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