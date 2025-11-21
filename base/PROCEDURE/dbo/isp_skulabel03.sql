SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure:  isp_SKULabel03                                     */
/* Creation Date: 15-Jul-2013                                           */
/* Copyright: IDS                                                       */
/* Written by: YTWan                                                    */
/*                                                                      */
/* Purpose:  SOS#281128 IDSCN                                           */
/*                                                                      */
/* Input Parameters: @c_StorerKey,  @c_SKU , @n_NoOfCopy                */
/*                                                                      */
/* Called By:  dw = r_dw_sku_label03                                    */
/*                                                                      */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/************************************************************************/
CREATE PROC [dbo].[isp_SKULabel03] (
      @c_StorerKey NVARCHAR(15) 
   ,  @c_Sku       NVARCHAR(30)
   ,  @c_NoOfCopy  NVARCHAR(10)
) 
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_StartTCnt          INT
         , @n_Continue           INT
         , @b_success            INT 
         , @n_err                INT 
         , @c_errmsg             NVARCHAR(255)
          
         , @n_Copy               INT
         , @n_NoOfCopy           INT
                                              
   SET @n_StartTCnt  = @@TRANCOUNT
   SET @n_Continue   = 1
   SET @b_success    = 1
   SET @n_err        = 0
   SET @c_errmsg     = ''
   SET @n_Copy       = 1
   SET @n_NoOfCopy   = CONVERT(INT, @c_NoOfCopy)

   WHILE @@TRANCOUNT > 0
   BEGIN
      COMMIT TRAN      
   END 

   CREATE TABLE #TEMPLABEL
      (  
         Storerkey      NVARCHAR(20)
      ,  Busr5          NVARCHAR(30) 
      ,  Busr6          NVARCHAR(30)         
      ,  Size           NVARCHAR(5) 
      ,  SkuCode        NVARCHAR(255) 
      ,  UPC            NVARCHAR(30)
      ,  Copy           INT         
      )

   

   INSERT INTO #TEMPLABEL 
      (Storerkey, Busr5, Busr6, Size, SkuCode, UPC, Copy)  
   SELECT Storerkey  = ISNULL(RTRIM(SKU.Storerkey),'')
         ,BUSR5      = ISNULL(RTRIM(SKU.BUSR5),'')
         ,BUSR6      = ISNULL(RTRIM(SKU.BUSR6),'')
         ,Size       = ISNULL(RTRIM(SKU.Size),'')
         ,SkuCode    = ISNULL(SKU.Notes2,'')
         ,UPC        = UPC.UPC
         ,Copy       = @n_Copy
   FROM SKU WITH (NOLOCK)
   JOIN UPC WITH (NOLOCK) ON (SKU.Storerkey = UPC.Storerkey) AND (SKU.Sku = UPC.Sku)
   WHERE SKU.Storerkey = @c_Storerkey
   AND   SKU.Sku = @c_sku 

   SET @n_err = @@ERROR
   IF @n_err <> 0
   BEGIN
      SET @n_Continue = 3
      SET @n_err = 30101
      SET @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Error Insert #TEMPLABEL. (isp_SKULabel03)' 
      GOTO QUIT
   END

   IF NOT EXISTS (SELECT 1 FROM #TEMPLABEL)
   BEGIN
      INSERT INTO #TEMPLABEL 
         (Storerkey, Busr5, Busr6, Size, SkuCode, UPC, Copy)  
      SELECT Storerkey  = ISNULL(RTRIM(SKU.Storerkey),'')
            ,BUSR5      = ISNULL(RTRIM(SKU.BUSR5),'')
            ,BUSR6      = ISNULL(RTRIM(SKU.BUSR6),'')
            ,Size       = ISNULL(RTRIM(SKU.Size),'')
            ,SkuCode    = ISNULL(SKU.Notes1,'')
            ,UPC        = UPC.UPC
            ,Copy       = @n_Copy
      FROM SKU WITH (NOLOCK)
      JOIN UPC WITH (NOLOCK) ON (SKU.Storerkey = UPC.Storerkey) AND (SKU.Sku = UPC.Sku)
      WHERE SKU.Storerkey = @c_Storerkey
      AND   UPC.UPC = @c_sku 

      SET @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SET @n_Continue = 3
         SET @n_err = 30102
         SET @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Error Insert #TEMPLABEL. (isp_SKULabel03)' 
         GOTO QUIT
      END
   END

   IF NOT EXISTS (SELECT 1 FROM #TEMPLABEL)
   BEGIN
      GOTO QUIT 
   END

   SET @n_NoOfCopy = @n_NoOfCopy - 1

   WHILE @n_NoOfCopy > 0
   BEGIN
      SET @n_Copy = @n_Copy + 1

      INSERT INTO #TEMPLABEL 
         (Storerkey, Busr5, Busr6, Size, SkuCode, UPC, Copy) 
      SELECT Storerkey
            ,Busr5
            ,BUSR6
            ,Size
            ,SkuCode
            ,UPC                                   
            ,@n_Copy
      FROM  #TEMPLABEL 
      WHERE Copy = 1

      SET @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SET @n_Continue = 3
         SET @n_err = 30103
         SET @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Error Insert #TEMPLABEL. (isp_SKULabel03)' 
         GOTO QUIT
      END

      SET @n_NoOfCopy = @n_NoOfCopy - 1
   END

   QUIT: 
   SELECT Storerkey
         ,Busr5
         ,BUSR6
         ,Size
         ,SkuCode
         ,UPC
   FROM  #TEMPLABEL 

   DROP TABLE #TEMPLABEL

   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN      
   END 

   IF @n_Continue = 3
   BEGIN
      IF @@TRANCOUNT > @n_StartTCnt
      BEGIN
         ROLLBACK TRAN
      END
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_SKULabel03'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      /* Error Did Not Occur , Return Normally */
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END

END

GO