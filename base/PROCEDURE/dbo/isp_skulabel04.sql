SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure:  isp_SKULabel04                                     */
/* Creation Date: 09-Sep-2014                                           */
/* Copyright: IDS                                                       */
/*                                                                      */
/* Purpose:  Jack Will - Kimball Label - GBP                            */
/*                                                                      */
/* Input Parameters:  @c_SKU , @n_NoOfCopy                              */
/*                                                                      */
/* Called By:  dw = r_dw_sku_label04                                    */
/*                                                                      */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver   Purposes                                  */
/* 08-Sep-2014  James   1.0   Created                                   */
/* 27-Feb-2015  NJOW01  1.1   334424-Change field mapping               */
/************************************************************************/
CREATE PROC [dbo].[isp_SKULabel04] (
   @c_StorerKey NVARCHAR(15),
   @c_SKU       NVARCHAR(20),
   @c_NoOfCopy  NVARCHAR(5), 
   @c_dropid    NVARCHAR(18) 
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

   DECLARE @n_NoOfCopy        INT
         , @c_ToteSku         NVARCHAR(20)
         , @c_Descr           NVARCHAR(60)
         , @c_Size            NVARCHAR(10)
         , @c_Price           NVARCHAR(15)
         , @c_AirportPrice    NVARCHAR(15)
         , @c_Currency        NVARCHAR(1)
         , @cConsigneeKey     NVARCHAR(15)
         , @nQty              INT 

   CREATE TABLE #TEMPLABEL (
           Sku                NVARCHAR(20) NULL
         , Descr              NVARCHAR(60) NULL 
         , Size               NVARCHAR(10) NULL          
         , Price              NVARCHAR(15) NULL
         , AirPortPrice       NVARCHAR(15) NULL
         , Currency           NVARCHAR(1)  NULL
         )                                                                

   SELECT @n_continue = 1, @n_starttcnt = @@TRANCOUNT 

   BEGIN TRAN 

   IF ISNUMERIC(@c_NoOfCopy) = 0
   BEGIN
      SET @n_NoOfCopy = 0
   END
   ELSE
   BEGIN
      SET @n_NoOfCopy = CAST(@c_NoOfCopy AS INT)
   END

   -- Get the 1st ConsigneeKey
   --SELECT TOP 1 @cConsigneeKey = ConsigneeKey FROM dbo.CONSIGNEESKU WITH (NOLOCK) ORDER BY 1
   DECLARE cur_Sku CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT Sku, SUM( QTY)
   FROM PACKDETAIL(NOLOCK) 
   WHERE DropID = @c_dropid
   AND Storerkey = @c_StorerKey
   GROUP BY SKU
   OPEN cur_Sku  
   FETCH NEXT FROM cur_Sku INTO @c_ToteSku, @nQty
   WHILE @@FETCH_STATUS = 0  
   BEGIN    

      SET @cConsigneeKey = 'JACKW1098'
      SELECT @c_Descr = SKU.Descr,
             @c_Size = ISNULL( SKU.Size,''), 
             --@c_Price = CONSIGNEESKU.UDF01, 
             --@c_AirPortPrice = CONSIGNEESKU.UDF03, 
             @c_AirPortPrice = CONSIGNEESKU.UDF01, --NJOW01
             @c_Currency = C2.Short 
      FROM dbo.SKU (NOLOCK) 
      LEFT JOIN CONSIGNEESKU (NOLOCK) ON SKU.Storerkey = CONSIGNEESKU.Storerkey AND SKU.Sku = CONSIGNEESKU.Sku 
      LEFT JOIN CODELKUP (NOLOCK) ON SKU.Busr3 = CODELKUP.Code AND CODELKUP.Listname = 'JWSIZE'
      LEFT JOIN CODELKUP C2 (NOLOCK) ON CONSIGNEESKU.UDF02 = C2.Code AND C2.Listname = 'CURRENCY'
      WHERE SKU.Storerkey = @c_StorerKey
      AND SKU.SKU = @c_ToteSku
      AND CONSIGNEESKU.ConsigneeKey = @cConsigneeKey
      
      --NJOW01 Start
      SELECT TOP 1 @cConsigneekey = Code
      FROM CODELKUP (NOLOCK)
      WHERE Listname = 'HISTPRICE'
      
      SELECT @c_Price = CONSIGNEESKU.UDF01 
      FROM dbo.SKU (NOLOCK) 
      LEFT JOIN CONSIGNEESKU (NOLOCK) ON SKU.Storerkey = CONSIGNEESKU.Storerkey AND SKU.Sku = CONSIGNEESKU.Sku 
      WHERE SKU.Storerkey = @c_StorerKey
      AND SKU.SKU = @c_ToteSku
      AND CONSIGNEESKU.ConsigneeKey = @cConsigneeKey
      --NJOW01 End

--      INSERT INTO TRACEINFO (TRACENAME, TIMEIN, COL1, COL2, COL3, COL4, COL5) values 
--      ('kimball', getdate(), @c_StorerKey, @c_ToteSku, @cConsigneeKey, @c_Price, @c_AirPortPrice)
      SET @c_NoOfCopy = @nQty
      
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
         INSERT INTO #TEMPLABEL 
            (Sku, Descr, Size, Price, AirportPrice, Currency)                                                        
         VALUES
            (@c_ToteSku, @c_Descr, @c_Size, @c_Price, @c_AirPortPrice, @c_Currency) 
      
         SET @n_err = @@ERROR
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63104   
      
            SELECT @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Insert #TEMPLABEL Failed. ' + 
                               ' (isp_SKULabel01)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
            GOTO EXIT_SP
         END
      
         SET @n_NoOfCopy = @n_NoOfCopy - 1
      END
      FETCH NEXT FROM cur_Sku INTO @c_ToteSku, @nQty
   END
   CLOSE cur_Sku
   DEALLOCATE cur_Sku 
      
   SELECT Sku
         ,Descr
         ,Size
         ,Price
         ,AirportPrice
         ,Currency
   FROM #TEMPLABEL
   ORDER BY Sku

   DROP TABLE #TEMPLABEL

   EXIT_SP: 
   IF @n_continue = 3
   BEGIN
      WHILE @@TRANCOUNT > @n_starttcnt
      ROLLBACK TRAN
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_SKULabel04'
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