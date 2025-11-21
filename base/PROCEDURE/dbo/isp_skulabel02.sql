SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure:  isp_SKULabel02                                     */
/* Creation Date: 29-Jun-2010                                           */
/* Copyright: IDS                                                       */
/* Written by: Vanessa                                                  */
/*                                                                      */
/* Purpose:  SOS#177739 Project Diana - Kimball Label - GBP             */
/*                                                                      */
/* Input Parameters:  @c_SKU , @n_NoOfCopy                              */
/*                                                                      */
/* Called By:  dw = r_dw_sku_label02                                    */
/*                                                                      */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 28-Sep-2011  YTWan   1.1   Add BUSR9 to label.(Wan01)                */
/* 17-AUG-2012  YTWan   1.2   SOS#253222:kimball Label EAN8 (Non German */
/*                            Stores) - (Wan02)                         */
/* 15-Apr-2014  TLTING    2.0   SQL2012 Compatible                      */
/************************************************************************/
CREATE PROC [dbo].[isp_SKULabel02] (
   @c_StorerKey NVARCHAR(15),
   @c_SKU       NVARCHAR(20),
   @c_NoOfCopy  NVARCHAR(5)
) 
AS
BEGIN
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE @n_continue        int,
           @c_errmsg          NVARCHAR(255),
           @b_success         int,
           @n_err             int,
           @n_starttcnt       int

   --(Wan02) - START
   --DECLARE @n_QTY           INT,
   --        @n_Count         INT,
   --        @c_DESCR         CHAR( 60),
   --        @c_SIZE          CHAR( 5),
   --        @n_COST          DECIMAL(12,2),
   --        @n_NoOfCopy      INT
   --      , @c_BUSR9         VARCHAR(30)                                                          --(Wan01)

   --CREATE TABLE #TEMPLABEL (
   --      SKU            VARCHAR(20),
   --      DESCR          VARCHAR(60),          
   --      SKUSize        VARCHAR(5),          
   --      COST           DECIMAL(12,2), 
   --      BUSR9          VARCHAR(30))                                                            --(Wan01)

   DECLARE @n_NoOfCopy        INT
         , @c_Descr           NVARCHAR(60)
         , @c_SkuGroup        NVARCHAR(10)
         , @c_Style           NVARCHAR(20)
         , @c_Color           NVARCHAR(20)
         , @c_Size            NVARCHAR(5)
         , @c_Busr9           NVARCHAR(30)
         , @n_Price           DECIMAL(12,2)
         , @n_Cost            DECIMAL(12,2)    

   CREATE TABLE #TEMPLABEL (
           Sku                NVARCHAR(20)
         , Descr              NVARCHAR(60) 
         , SkuGroup           NVARCHAR(10)
         , Style              NVARCHAR(20)
         , Color              NVARCHAR(20)         
         , Size               NVARCHAR(5)          
         , Busr9              NVARCHAR(30)
         , Price              DECIMAL(12,2)
         , Cost               DECIMAL(12,2)  
         )                                                                
   --(Wan02) - END

   SELECT @n_continue = 1, @n_starttcnt = @@TRANCOUNT 

   BEGIN TRAN

   --(Wan02) - START
   SELECT @c_Sku = ISNULL(RTRIM(Sku),'') 
         ,@c_Descr = ISNULL(SUBSTRING(RTRIM(Descr),1,20),'') 
         ,@c_SkuGroup=ISNULL(RTRIM(SkuGroup),'') 
         ,@c_Style = ISNULL(SUBSTRING(RTRIM(Style),1,5),'') 
         ,@c_Color = ISNULL(RTRIM(Color),'') 
         ,@c_Size  = ISNULL(RTRIM(Size),'')
         ,@c_Busr9 = ISNULL(RTRIM(Busr9),'')   
         ,@n_Price = ISNULL(Price,0.00)
         ,@n_Cost  = ISNULL(Cost,0.00)
   FROM SKU WITH (NOLOCK) 
   WHERE StorerKey = @c_StorerKey
   AND SKU = @c_SKU

   --SELECT @c_SKU = SKU, @c_DESCR = DESCR, @c_SIZE = SIZE, @n_COST = COST
   --      ,@c_BUSR9 = ISNULL(RTRIM(BUSR9),'')                                                       --(Wan01)
   --FROM SKU WITH (NOLOCK) 
   --WHERE StorerKey = @c_StorerKey
   --   AND SKU = @c_SKU
   --(Wan02) - END

   IF ISNUMERIC(@c_NoOfCopy) = 0
   BEGIN
      SET @n_NoOfCopy = 0
   END
   ELSE
   BEGIN
      SET @n_NoOfCopy = CAST(@c_NoOfCopy AS INT)
   END
   
   WHILE @n_NoOfCopy > 0
   BEGIN
      --(Wan02) - START
      INSERT INTO #TEMPLABEL 
         (Sku, Descr, SkuGroup, Style, Color, Size, Busr9, Price, Cost)                                                        
      VALUES
         (@c_Sku, @c_Descr, @c_SkuGroup, @c_Style, @c_Color, @c_Size, @c_Busr9, @n_Price, @n_Cost)                                            

      --INSERT INTO #TEMPLABEL 
      --   (SKU, DESCR, SKUSize, COST, BUSR9)                                                        --(Wan01)
      --VALUES
      --   (@c_SKU, @c_DESCR, @c_SIZE, @n_COST, @c_BUSR9)                                            --(Wan01)
      --(Wan02) - END

      SET @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63104   
         SELECT @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Insert #TEMPLABEL Failed. ' + 
                            ' (isp_SKULabel02)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
         GOTO EXIT_SP
      END

      SET @n_NoOfCopy = @n_NoOfCopy - 1
   END


   -- Retrieve values
   --(Wan02) - START
   SELECT Sku
         ,Descr
         ,SkuGroup
         ,Style
         ,Color
         ,Size
         ,Busr9
         ,Price
         ,Cost
   FROM #TEMPLABEL

   --SELECT UPPER(SKU), RTRIM(LTRIM(DESCR)), SKUSize, Cost
   --      ,ISNULL(RTRIM(BUSR9),'')                                                                  --(Wan01)
   --FROM #TEMPLABEL
   --(Wan02) - END
   DROP TABLE #TEMPLABEL

   EXIT_SP: 
   IF @n_continue = 3
   BEGIN
      WHILE @@TRANCOUNT > @n_starttcnt
      ROLLBACK TRAN
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_SKULabel02'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      /* Error Did Not Occur , Return Normally */
      WHILE @@TRANCOUNT > @n_starttcnt
         COMMIT TRAN
      RETURN
   END

END

GO