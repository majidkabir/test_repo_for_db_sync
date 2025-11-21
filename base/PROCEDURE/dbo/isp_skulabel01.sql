SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure:  isp_SKULabel01                                     */
/* Creation Date: 29-Jun-2010                                           */
/* Copyright: IDS                                                       */
/* Written by: Vanessa                                                  */
/*                                                                      */
/* Purpose:  SOS#177739 Project Diana - Kimball Label - GBP             */
/*                                                                      */
/* Input Parameters:  @c_SKU , @n_NoOfCopy                              */
/*                                                                      */
/* Called By:  dw = r_dw_sku_label01                                    */
/*                                                                      */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver   Purposes                                  */
/* 28-Sep-2011  YTWan   1.1   Add BUSR9 to label.(Wan01)                */
/* 17-AUG-2012  YTWan   1.2   SOS#253220:kimball Label EAN13 (German    */
/*                            Stores) - (Wan02)                         */
/* 15-Apr-2014  TLTING  1.3   SQL2012 Compatible                        */
/* 23-Jul-2014  NJOW01  1.4   316181-Change for Jack Wills              */
/* 28-Aug-2014  James   1.5   316182- Add currency symbol (james01)     */
/* 01-Oct-2014  James   1.6   Change lingkage between dropid and        */
/*                            packheader using only loadkey (james02)   */
/* 03-Jul-2015  NJOW02  1.7   334424-Apply UDF01 price ignore UDF03     */
/************************************************************************/
CREATE PROC [dbo].[isp_SKULabel01] (
   @c_StorerKey NVARCHAR(15),
   @c_SKU       NVARCHAR(20),
   @c_NoOfCopy  NVARCHAR(5),
   @c_DropID    NVARCHAR(20)
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
         , @c_Currency        NVARCHAR(1)
         , @nQty              INT 
         , @cConsigneeKey     NVARCHAR(15)

   CREATE TABLE #TEMPLABEL (
           Sku                NVARCHAR(20) NULL
         , Descr              NVARCHAR(60) NULL 
         , Size               NVARCHAR(10) NULL          
         , Price              NVARCHAR(15) NULL
         , Currency           NVARCHAR(1)  NULL
         )                                                                

   SELECT @n_continue = 1, @n_starttcnt = @@TRANCOUNT 

   BEGIN TRAN 
   
   IF @c_NoOfCopy = 999
   BEGIN
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

         SET @c_Descr = ''
         SET @c_Size = ''
         SET @c_Price = ''
         SET @c_Currency = ''

         SELECT @c_Descr = SKU.Descr,
                @c_Size = ISNULL(CASE WHEN ORDERS.C_ISOCntryCode = 'USA' THEN CODELKUP.UDF01 ELSE SKU.Size END,''),
                @c_Price = CONSIGNEESKU.UDF01,   --NJOW02
                --@c_Price = ISNULL(CASE WHEN ISNULL(CONSIGNEESKU.UDF03,'') <> '' THEN CONSIGNEESKU.UDF03 ELSE CONSIGNEESKU.UDF01 END,''), 
                @c_Currency = C2.Short -- (james01)
         FROM DROPID(NOLOCK) 
--         JOIN PACKHEADER(NOLOCK) ON DROPID.Pickslipno = PACKHEADER.Pickslipno
         JOIN PACKHEADER(NOLOCK) ON DROPID.LoadKey = PACKHEADER.LoadKey -- (james02)
         JOIN PACKDETAIL(NOLOCK) ON PACKHEADER.Pickslipno = PACKDETAIL.Pickslipno
         JOIN ORDERS (NOLOCK) ON PACKHEADER.Orderkey = ORDERS.Orderkey
         JOIN SKU (NOLOCK) ON PACKDETAIL.Storerkey = SKU.Storerkey AND PACKDETAIL.Sku = SKU.Sku
         LEFT JOIN CONSIGNEESKU (NOLOCK) ON SKU.Storerkey = CONSIGNEESKU.Storerkey AND SKU.Sku = CONSIGNEESKU.Sku 
                                    AND ORDERS.Consigneekey = CONSIGNEESKU.Consigneekey
         LEFT JOIN CODELKUP (NOLOCK) ON SKU.Busr3 = CODELKUP.Code AND CODELKUP.Listname = 'JWSIZE'
         LEFT JOIN CODELKUP C2 (NOLOCK) ON CONSIGNEESKU.UDF02 = C2.Code AND C2.Listname = 'CURRENCY'
         WHERE PACKDETAIL.DropID = @c_dropid
         AND PACKDETAIL.SKU = @c_ToteSku
         AND SKU.Storerkey = @c_StorerKey

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
               (Sku, Descr, Size, Price, Currency)                                                        
            VALUES
               (@c_ToteSku, @c_Descr, @c_Size, @c_Price, @c_Currency) 
         
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
   END
   ELSE
   IF ISNULL( @c_DropID, '') <> ''
   BEGIN
      SET @c_ToteSku = ''
      SET @c_Descr = ''
      SET @c_Size = ''
      SET @c_Price = ''
      SET @c_Currency = ''
         
      DECLARE cur_Sku CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT DISTINCT SKU.Sku,
                SKU.Descr,
                ISNULL(CASE WHEN ORDERS.C_ISOCntryCode = 'USA' THEN CODELKUP.UDF01 ELSE SKU.Size END,'') AS Size,
                CONSIGNEESKU.UDF01 AS Price,   --NJOW02
                --ISNULL(CASE WHEN ISNULL(CONSIGNEESKU.UDF03,'') <> '' THEN CONSIGNEESKU.UDF03 ELSE CONSIGNEESKU.UDF01 END,'') AS Price, 
                C2.Short AS Currency -- (james01)
         FROM DROPID(NOLOCK) 
--         JOIN PACKHEADER(NOLOCK) ON DROPID.Pickslipno = PACKHEADER.Pickslipno
         JOIN PACKHEADER(NOLOCK) ON DROPID.LoadKey = PACKHEADER.LoadKey -- (james02)
         JOIN PACKDETAIL(NOLOCK) ON PACKHEADER.Pickslipno = PACKDETAIL.Pickslipno
         JOIN ORDERS (NOLOCK) ON PACKHEADER.Orderkey = ORDERS.Orderkey
         JOIN SKU (NOLOCK) ON PACKDETAIL.Storerkey = SKU.Storerkey AND PACKDETAIL.Sku = SKU.Sku
         LEFT JOIN CONSIGNEESKU (NOLOCK) ON SKU.Storerkey = CONSIGNEESKU.Storerkey AND SKU.Sku = CONSIGNEESKU.Sku 
                                    AND ORDERS.Consigneekey = CONSIGNEESKU.Consigneekey
         LEFT JOIN CODELKUP (NOLOCK) ON SKU.Busr3 = CODELKUP.Code AND CODELKUP.Listname = 'JWSIZE'
         LEFT JOIN CODELKUP C2 (NOLOCK) ON CONSIGNEESKU.UDF02 = C2.Code AND C2.Listname = 'CURRENCY'
         WHERE PACKDETAIL.DropID = @c_dropid
         AND SKU.Storerkey = @c_StorerKey
               
      OPEN cur_Sku  
      FETCH NEXT FROM cur_Sku INTO @c_ToteSku, @c_Descr, @c_Size, @c_Price, @c_Currency 

      WHILE @@FETCH_STATUS = 0  
      BEGIN    
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
               (Sku, Descr, Size, Price, Currency)                                                        
            VALUES
               (@c_ToteSku, @c_Descr, @c_Size, @c_Price, @c_Currency) 
         
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
         
         FETCH NEXT FROM cur_Sku INTO @c_ToteSku, @c_Descr, @c_Size, @c_Price, @c_Currency
      END
      CLOSE cur_Sku 
      DEALLOCATE cur_Sku                                           
   END
   ELSE
   BEGIN
      SET @c_Descr = ''
      SET @c_Size = ''
      SET @c_Price = ''
      SET @c_Currency = ''
      SET @cConsigneeKey = ''

      -- Get the 1st ConsigneeKey
      SELECT TOP 1 @cConsigneeKey = ConsigneeKey FROM dbo.CONSIGNEESKU WITH (NOLOCK) WHERE CONSIGNEESKU = @c_Sku ORDER BY 1
      
      SELECT @c_Descr = SKU.Descr,
             @c_Size = ISNULL( SKU.Size,''), 
             @c_Price = CONSIGNEESKU.UDF01, 
             @c_Currency = C2.Short -- (james01)
      FROM dbo.SKU (NOLOCK) 
      LEFT JOIN CONSIGNEESKU (NOLOCK) ON SKU.Storerkey = CONSIGNEESKU.Storerkey AND SKU.Sku = CONSIGNEESKU.Sku 
      LEFT JOIN CODELKUP (NOLOCK) ON SKU.Busr3 = CODELKUP.Code AND CODELKUP.Listname = 'JWSIZE'
      LEFT JOIN CODELKUP C2 (NOLOCK) ON CONSIGNEESKU.UDF02 = C2.Code AND C2.Listname = 'CURRENCY'
      WHERE SKU.Storerkey = @c_StorerKey
      AND SKU.SKU = @c_Sku
      AND CONSIGNEESKU.ConsigneeKey = @cConsigneeKey
      
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
            (Sku, Descr, Size, Price, Currency)                                                        
         VALUES
            (@c_Sku, @c_Descr, @c_Size, @c_Price, @c_Currency) 
      
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
   END
   

   SELECT Sku
         ,Descr
         ,Size
         ,Price
         ,Currency
   FROM #TEMPLABEL
   ORDER BY Sku

   DROP TABLE #TEMPLABEL

   EXIT_SP: 
   IF @n_continue = 3
   BEGIN
      WHILE @@TRANCOUNT > @n_starttcnt
      ROLLBACK TRAN
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_SKULabel01'
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