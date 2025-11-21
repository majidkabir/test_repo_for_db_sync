SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/ 
/* Object Name: isp_ea_tax_invoice                                         */
/* Modification History:                                                   */  
/*                                                                         */  
/* Called By:  Exceed                                                      */
/*                                                                         */
/* PVCS Version: 1.0                                                       */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Date         Author    Ver.  Purposes                                   */
/* 05-Aug-2002            1.0   Initial revision                           */
/* 14-Mar-2012  KHLim01   1.1   Update EditDate                            */
/***************************************************************************/   
CREATE PROC [dbo].[isp_ea_tax_invoice] (
@c_storerkey nvarchar(15),
@c_inv_no nvarchar(10),
@c_confirm nvarchar(1),
@c_reprint nvarchar(1))
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_status nvarchar(1),
           @c_wms_inv nvarchar(10),
           @c_EAInvoiceKey nvarchar(10),
           @b_success int,
           @n_err int,
           @c_errmsg nvarchar(250),
           @c_ncounter_key nvarchar(30),
           @c_inv_found nvarchar(10)

   IF @c_reprint = 'Y'
      SELECT
         @c_wms_inv = userdefine01,
         @c_status = status,
         @c_inv_found = invoiceno
      FROM orders(nolock)
      WHERE userdefine01 = @c_inv_no
   ELSE
      SELECT
         @c_wms_inv = userdefine01,
         @c_status = status,
         @c_inv_found = invoiceno
      FROM orders(nolock)
      WHERE invoiceno = @c_inv_no

   IF @@rowcount = 0
      SELECT
         '',
         '01-01-1900',
         '',
         '',
         '',
         '',
         '',
         '',
         '',
         '',
         '',
         '',
         '',
         '',
         '',
         '',
         0

   IF ((@c_wms_inv IS NULL)
      OR (@c_wms_inv = ''))
      AND (@c_inv_found IS NOT NULL)
   BEGIN
      IF @c_confirm = 'Y'
      BEGIN
         SET @c_ncounter_key = dbo.fnc_LTrim(dbo.fnc_RTrim(@c_storerkey)) + 'InvoiceKey'
         EXECUTE nspg_getkey @c_ncounter_key,
                             10,
                             @c_EAInvoiceKey OUTPUT,
                             @b_success OUTPUT,
                             @n_err OUTPUT,
                             @c_errmsg OUTPUT
         IF @b_success = 1
            UPDATE orders
            SET userdefine01 = @c_EAInvoiceKey,
                printflag = 'Y',
                userdefine02 = '1',
                trafficcop = NULL,
                EditDate = GETDATE() -- KHLim01
            WHERE invoiceno = @c_inv_no
      END

      IF @c_status = '5'
      BEGIN
         SELECT
            a.userdefine01,
            a.userdefine06,
            a.b_company,
            a.b_address1,
            a.b_address2,
            a.b_address3,
            a.b_address4,
            a.b_country,
            a.b_zip,
            a.externorderkey,
            a.buyerpo,
            a.pmtterm,
            a.b_vat,
            a.invoiceno,
            d.b_company,
            d.company,
            CASE ISNUMERIC(a.userdefine03)
               WHEN 1 THEN CAST(a.userdefine03 AS decimal(10, 2))
               ELSE 0.00
            END
         FROM orders a (NOLOCK),
              storer d (NOLOCK)
         WHERE a.storerkey = d.storerkey
         AND a.invoiceno = @c_inv_no
         AND a.storerkey = @c_storerkey
      END
      ELSE
      IF @c_status = '9'
      BEGIN
         SELECT
            a.userdefine01,
            a.userdefine06,
            a.b_company,
            a.b_address1,
            a.b_address2,
            a.b_address3,
            a.b_address4,
            a.b_country,
            a.b_zip,
            a.externorderkey,
            a.buyerpo,
            a.pmtterm,
            a.b_vat,
            a.invoiceno,
            d.b_company,
            d.company,
            CASE ISNUMERIC(a.userdefine03)
               WHEN 1 THEN CAST(a.userdefine03 AS decimal(10, 2))
               ELSE 0.00
            END
         FROM orders a (NOLOCK),
              storer d (NOLOCK)
         WHERE a.storerkey = d.storerkey
         AND a.invoiceno = @c_inv_no
         AND a.storerkey = @c_storerkey
      END
   END
   ELSE
   BEGIN
      IF @c_reprint = 'Y'
         AND @c_confirm = 'N'
      BEGIN
         IF @c_status = '5'
         BEGIN
            SELECT
               a.userdefine01,
               a.userdefine06,
               a.b_company,
               a.b_address1,
               a.b_address2,
               a.b_address3,
               a.b_address4,
               a.b_country,
               a.b_zip,
               a.externorderkey,
               a.buyerpo,
               a.pmtterm,
               a.b_vat,
               a.invoiceno,
               d.b_company,
               d.company,
               CASE ISNUMERIC(a.userdefine03)
                  WHEN 1 THEN CAST(a.userdefine03 AS decimal(10, 2))
                  ELSE 0.00
               END
            FROM orders a (NOLOCK),
                 storer d (NOLOCK)
            WHERE a.storerkey = d.storerkey
            AND a.userdefine01 = @c_inv_no
            AND a.storerkey = @c_storerkey
         END
         ELSE
         IF @c_status = '9'
         BEGIN
            SELECT
               a.userdefine01,
               a.userdefine06,
               a.b_company,
               a.b_address1,
               a.b_address2,
               a.b_address3,
               a.b_address4,
               a.b_country,
               a.b_zip,
               a.externorderkey,
               a.buyerpo,
               a.pmtterm,
               a.b_vat,
               a.invoiceno,
               d.b_company,
               d.company,
               CASE ISNUMERIC(a.userdefine03)
                  WHEN 1 THEN CAST(a.userdefine03 AS decimal(10, 2))
                  ELSE 0.00
               END
            FROM orders a (NOLOCK),
                 storer d (NOLOCK)
            WHERE a.storerkey = d.storerkey
            AND a.userdefine01 = @c_inv_no
            AND a.storerkey = @c_storerkey
         END

         UPDATE orders
         SET UserDefine02 = CONVERT(nvarchar(20), (CONVERT(integer, UserDefine02) + 1))
         WHERE userdefine01 = @c_inv_no
      END
      ELSE -- if @c_reprint <> 'Y' and @c_confirm <> 'N'
         SELECT
            '',
            '01-01-1900',
            '',
            '',
            '',
            '',
            '',
            '',
            '',
            '',
            '',
            '',
            '',
            '',
            '',
            '',
            0


   END

END


GO