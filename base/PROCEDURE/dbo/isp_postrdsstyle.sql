SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc : isp_PostRdsStyle          			      	            */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:     YTWAN                                                */
/*                                                                      */
/* Purpose:   POST RDSSTyle to SKU Table 	          		               */
/*                                                                      */
/* Input Parameters: @c_Storerkey,                                      */
/*                   @c_Style                                           */
/*                                                                      */
/* Output Parameters: @b_Success,                                       */
/*                    @n_err,                                           */
/*                    @c_errmsg                                         */
/*                                                                      */
/*                                                                      */
/* Return Status: b_Success = 0 or 1                                    */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By: RDS Style Posting  			                                  */
/*                                                                      */
/* PVCS Version: 1.1       -- Change this PVCS next version release     */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date          Author    Ver.  Purposes                               */
/* 06-Nov-2008   Ytwan     1.1   SOS#103756 Foreignkey Constraint Fixes */	
/************************************************************************/


CREATE PROC [dbo].[isp_PostRdsStyle] (
   @c_Storerkey  NVARCHAR(15),
   @c_Style      NVARCHAR(20), 
   @b_Success    int OUTPUT,
	@n_err        int OUTPUT,
	@c_errmsg     NVARCHAR(215) OUTPUT)
AS 
BEGIN
 SET NOCOUNT ON  
 SET QUOTED_IDENTIFIER OFF   
 SET ANSI_NULLS OFF 
 SET CONCAT_NULL_YIELDS_NULL OFF 

   DECLARE @c_GarmentType     NVARCHAR(18), 
           @c_HangFlat        NVARCHAR(18),
           @c_SeasonCode      NVARCHAR(18), 
           @c_TrackBySeason   NVARCHAR(18),
           @c_PO              NVARCHAR(18),
           @c_TrackByPO       NVARCHAR(18),
           @c_Gender          NVARCHAR(10),
           @c_Division        NVARCHAR(18),
           @c_nmfcClass       NVARCHAR(30),
           @c_nmfcCode        NVARCHAR(15),
           @c_Remarks         nvarchar(4000),
           @c_Seq             NVARCHAR(30),
           @c_Color           NVARCHAR(10),
           @c_Size            NVARCHAR(5),
           @c_Measurement     NVARCHAR(5),
           @c_upc             NVARCHAR(30),
           @c_SkuDescr        NVARCHAR(50), 
           @c_StyleDescr      NVARCHAR(30),
           @c_PackUOM3        NVARCHAR(10),
           @c_PackKey         NVARCHAR(10),
           @c_PriorStyle      NVARCHAR(20),
           @c_PriorColor      NVARCHAR(10),
           @n_Continue         int, 
           @n_StartTCnt        int

   SET @n_StartTCnt=@@TRANCOUNT 
   SET @n_Continue=1 

   BEGIN TRAN 

   DECLARE Csr_StyleColorSize CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT rdsStyle.StyleDescr,
          rdsStyle.GarmentType,
          rdsStyle.HangFlat,
          rdsStyle.Seasoncode, 
          rdsStyle.PO,
          rdsStyle.Gender,
          rdsStyle.Division,
          rdsStyle.nmfcclass,
          rdsStyle.nmfccode,
          CAST( rdsStyle.Remarks AS nvarchar(4000)),
          rdsStyleColorSize.Seqno,
          rdsStyleColorSize.Color,
          rdsStyleColorSize.Sizes,
          rdsStyleColorSize.Measurement,
          rdsStyleColorSize.UPC
   FROM rdsStyle WITH (NOLOCK) 
   JOIN rdsStyleColorSize WITH (NOLOCK)
     ON ( rdsStyle.Style = rdsStyleColorSize.Style )
   WHERE rdsStyle.Storerkey = @c_Storerkey
     AND rdsStyle.Style = @c_Style
     AND rdsStyleColorSize.Status = '0' -- SOS#103756 2008-11-06 YTWan Foreignkey Constraint Fixed

   OPEN Csr_StyleColorSize
   FETCH NEXT FROM Csr_StyleColorSize INTO 
          @c_StyleDescr ,@c_GarmentType   ,@c_HangFlat     ,@c_SeasonCode    ,@c_PO   
         ,@c_gender     ,@c_division      ,@c_nmfcclass    ,@c_nmfccode      ,@c_remarks     
         ,@c_seq        ,@c_color         ,@c_size         ,@c_measurement   ,@c_upc         

   WHILE @@FETCH_STATUS <> -1
   BEGIN

      IF @c_PriorStyle <>  @c_Style
      BEGIN

         SELECT @c_packkey = Short
         FROM  CODELKUP WITH (NOLOCK)
         WHERE CODELKUP.ListName = 'HANGFLAT'
         AND   CODELKUP.Code     = @c_HangFlat

         IF @c_HangFlat = 'H'
         BEGIN
            SET @c_packuom3 = 'GOH'
         END
         ELSE IF @c_HangFlat = 'F'
         BEGIN
            SET @c_packuom3 = 'PC'
         END 
      
         IF @c_Seasoncode = 'Y'
--            SET @c_TrackBySeason = 'SEASONCODE'
		      SET @c_TrackBySeason = 'SEASON' --AAY001
         ELSE IF @c_Seasoncode = 'N'
            SET @c_TrackBySeason = ''
   
         IF @c_PO = 'Y'
--            SET @c_TrackByPO = 'LOT'
			  SET @c_TrackByPO = 'CUT_LOT_PO' --AAY001
         ELSE IF @c_PO = 'N'
            SET @c_TrackByPO = ''
      END 
   
      SET @c_Skudescr = dbo.fnc_RTrim(@c_style) + '_' + dbo.fnc_RTrim(@c_Color) + '_' + dbo.fnc_RTrim(@c_Size)  
      
      IF ISNULL(dbo.fnc_RTrim(@c_Measurement),'') <> '' 
      BEGIN
         SET @c_Skudescr = @c_Skudescr + '_' +  ISNULL(dbo.fnc_RTrim(@c_Measurement),'')
      END 
      ELSE  -- Added By Ricky to default the Measurement to blank instead of Null
      BEGIN
      	SET @c_Measurement = ''
      END

      IF EXISTS(SELECT 1 FROM SKU WITH (NOLOCK) WHERE Storerkey = @c_StorerKey AND SKU = @c_upc)
      BEGIN

         IF EXISTS(SELECT 1 FROM SKUxLOC WITH (NOLOCK) WHERE Storerkey = @c_Storerkey AND Sku = @c_upc AND Qty > 0)
         BEGIN

            SET @n_Continue = 3
            SET @b_Success = -1
            SET @n_err = 60001
            SET @c_errmsg = 'There are Inventory for Style:' + dbo.fnc_RTrim(@c_Style) + '. No Update Allow'
            GOTO QUIT 
         END

         DELETE SKU 
         WHERE  Storerkey = @c_StorerKey
         AND    Sku       = @c_UPC
         SET @n_Err = @@ERROR
         IF @n_Err <> 0 
         BEGIN
            SET @n_Continue = 3
            SET @b_success = -1
            SET @c_ErrMsg = 'Delete Sku Failed!'
            GOTO QUIT
         END
      END 

      IF NOT EXISTS(SELECT 1 FROM PACK WITH (NOLOCK) WHERE PACKKEY = @c_Packkey)
      BEGIN 
         -- This is New PACKKEY
         INSERT INTO [PACK]
              ([Packkey]   ,[PackDescr]   ,[PackUOM3]   ,[Qty])
         VALUES
              (@c_Packkey  ,@c_Packkey    ,@c_packuom3  ,1)
      END

      IF NOT EXISTS(SELECT 1 FROM SKU WITH (NOLOCK) WHERE StorerKey = @c_StorerKey AND SKU = @c_upc)
      BEGIN 
         -- This is New Orders
         INSERT INTO [SKU]
              ([StorerKey]          ,[Sku]                ,[Descr]
              ,[Packkey]            ,[Lottable01Label]    ,[Lottable02Label]
              ,[Lottable05Label]    ,[SUSR3]              ,[ItemClass]                       
              ,[Class]              ,[BUSR1]              ,[BUSR3]              
              ,[BUSR6]              ,[BUSR8]              ,[Notes1]             
              ,[Style]              ,[Color]              ,[Size]               
              ,[Measurement]        ,[Active]             ,[ShelfLife]          
              ,[TolerancePct]		,[Susr4])
         VALUES
              (@c_Storerkey         ,@c_upc               ,@c_SkuDescr          
              ,@c_Packkey           ,@c_TrackBySeason     ,@c_TrackByPO
--              ,'ReceiptDate'        ,@c_Division          ,@c_GarmentType       
              ,'RCP_DATE'        ,@c_Division          ,@c_GarmentType       
              ,@c_Gender            ,@c_StyleDescr        ,@c_nmfcClass         
              ,@c_nmfcCode          ,@c_Seq               ,@c_Remarks           
              ,@c_Style             ,@c_Color             ,@c_Size              
              ,@c_Measurement       ,'1'                  ,0                    
              ,10.00				,'10')
   
         SET @n_Err = @@ERROR
         IF @n_Err <> 0 
         BEGIN
            SET @n_Continue = 3
            SET @b_success = -1
            SET @c_ErrMsg = 'Insert SKU Failed!'
            GOTO QUIT
         END
         ELSE
         BEGIN
            IF @c_priorstyle <>  @c_style
            BEGIN
               UPDATE rdsStyle 
                  SET Status = '9' 
               WHERE Storerkey = @c_Storerkey
               AND   Style     = @c_style
   
               SET @n_Err = @@ERROR
               IF @n_Err <> 0 
               BEGIN
                  SET @n_Continue = 3
                  SET @b_success = -1
                  SET @c_ErrMsg = 'UPDATE rdsStyle Failed!'
                  GOTO QUIT
               END
            END
            IF @c_PriorColor <>  @c_Color
            BEGIN
               UPDATE rdsStyleColor 
                  SET Status = '9' 
               WHERE Storerkey = @c_Storerkey
               AND   Style     = @c_Style
               AND   Color     = @c_Color
   
               SET @n_Err = @@ERROR
               IF @n_Err <> 0 
               BEGIN
                  SET @n_Continue = 3
                  SET @b_success = -1
                  SET @c_ErrMsg = 'UPDATE rdsStyleColor Failed!'
                  GOTO QUIT
               END
            END

            UPDATE rdsStyleColorSize 
            SET Status = '9' 
            WHERE Storerkey = @c_Storerkey
            AND   Style     = @c_Style
            AND   Color     = @c_Color
            AND   Sizes     = @c_Size
   
            SET @n_Err = @@ERROR
            IF @n_Err <> 0 
            BEGIN
               SET @n_Continue = 3
               SET @b_success = -1
               SET @c_ErrMsg = 'UPDATE rdsStyleColorSize Failed!'
               GOTO QUIT
            END
         END 
      END
      SET @c_PriorStyle = @c_Style
      SET @c_PriorColor = @c_color

      FETCH NEXT FROM Csr_StyleColorSize INTO 
             @c_StyleDescr ,@c_GarmentType   ,@c_HangFlat     ,@c_SeasonCode    ,@c_PO    
            ,@c_gender     ,@c_division      ,@c_nmfcclass       ,@c_nmfccode      ,@c_remarks     
            ,@c_seq        ,@c_color         ,@c_size            ,@c_measurement   ,@c_upc         
      
   END -- While Csr_StyleColorSize cursor loop
   CLOSE Csr_StyleColorSize
   DEALLOCATE Csr_StyleColorSize
QUIT:
   IF @n_continue = 3  -- Error Occured - Process And Return
   BEGIN

      SELECT @b_success = 0

      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_starttcnt
      BEGIN
         ROLLBACK TRAN
      END
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_PostRdsStyle'
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