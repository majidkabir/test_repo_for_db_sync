SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: isp_Delivery_Receipt03                             */
/* Creation Date: 07-APR-2010                                           */
/* Copyright: IDS                                                       */
/* Written by: GTGOH (Modify from isp_Delivery_Receipt01)               */
/*                                                                      */
/* Purpose: ULP Delivery Receipt (SOS167852)                            */
/*                                                                      */
/* Called By: r_dw_delivery_receipt03                                   */
/*                                                                      */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author     Ver   Purposes                               */
/* 06-Jul-2010  Leong      1.1   SOS# 177468 - Check MOBL.Status instead*/
/*                                             of Orders.Status         */
/* 14-Mar-2012 KHLim01     1.2   Update EditDate                        */       
/************************************************************************/

CREATE PROC [dbo].[isp_Delivery_Receipt03] (@cMBOLkey NVARCHAR(10))
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cStorerkey     NVARCHAR(15)
         , @cUserdefine10  NVARCHAR(10)
         , @cDRCounterKey  NVARCHAR(10)
         , @cCurrExternKey NVARCHAR(30)
         , @cPrevExternKey NVARCHAR(30)
         , @cCurrSKU       NVARCHAR(20)
         , @cPrevSKU       NVARCHAR(20)
         , @nSeqNum        int
         , @nTotalOrderQty int
         , @cPrintFlag     NVARCHAR(1)
         , @nRecCnt        int
         , @cInvoiceNo     NVARCHAR(20)
         , @cC_Company     NVARCHAR(45)

   DECLARE @n_err          int
         , @n_continue     int
         , @b_success      int
         , @c_errmsg       NVARCHAR(255)
         , @n_starttcnt    int
         , @b_debug        int

   CREATE TABLE #TempFlag (
      InvoiceNo    [char] (20) NULL,
      PrintFlag    [char] (1)  NULL,
      C_Company    [char] (45) NULL )

   CREATE CLUSTERED INDEX [PK_tempFlag] on #TempFlag (InvoiceNo)

   SELECT @n_starttcnt = @@TRANCOUNT, @n_continue = 1, @b_debug = 0, @n_err = 0

   SET @cPrintFlag = ''
   SET @nRecCnt = 0

   -- SOS# 177468 Start
   --SELECT @nRecCnt = COUNT(1) FROM ORDERS WITH (NOLOCK)
   --WHERE MBOLKey = @cMBOLkey

   --IF @nRecCnt <= 0

   IF NOT EXISTS ( SELECT DISTINCT 1
                   FROM MBOLDetail MD WITH (NOLOCK)
                   JOIN ORDERS O WITH (NOLOCK)
                   ON (MD.OrderKey = O.OrderKey)
                   WHERE MD.MBOLKey = @cMBOLkey )
   BEGIN
      SELECT @n_continue = 3
      SELECT @n_err = 63500
      SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": No ORDERS populated to MBOL. (isp_Delivery_Receipt03)"
   END
   -- SOS# 177468 End
   ELSE
   BEGIN
      -- SOS# 177468 Start

      --SELECT @nRecCnt = COUNT(1) FROM ORDERS WITH (NOLOCK)
      --WHERE MBOLKey = @cMBOLkey
      --AND RTRIM(ISNULL(InvoiceNo,'')) <> '' AND Status <> '9'

      --IF @nRecCnt > 0

      IF EXISTS( SELECT 1 FROM MBOL M WITH (NOLOCK)
                 JOIN MBOLDetail MD WITH (NOLOCK)
                 ON (M.MBOLKey = MD.MBOLKey)
                 WHERE M.MBOLKey = @cMBOLkey
                 AND ISNULL(RTRIM(MD.InvoiceNo),'') <> '' AND M.Status <> '9' )
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 63501
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": MBOL not yet shipped. (isp_Delivery_Receipt03)"
      END
      --SOS# 177468 End
   END

-- Assign DR Number (at InvoiceNo level) to all orders under this MBOLKey!
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      DECLARE CurOrderGroup CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT StorerKey, ISNULL(RTRIM(UserDefine10),''), ISNULL(RTRIM(C_Company),''), ISNULL(RTRIM(InvoiceNo),'')
         FROM ORDERS WITH (NOLOCK)
         WHERE MBOLKey = @cMBOLkey
         GROUP BY StorerKey, ISNULL(RTRIM(UserDefine10),''), ISNULL(RTRIM(C_Company),''), ISNULL(RTRIM(InvoiceNo),'')
         ORDER BY ISNULL(RTRIM(UserDefine10),''), ISNULL(RTRIM(C_Company),'')

      OPEN CurOrderGroup
      FETCH NEXT FROM CurOrderGroup INTO @cStorerkey, @cUserDefine10, @cC_Company, @cInvoiceNo

      WHILE @@FETCH_STATUS <> -1 -- CurOrderGroup Loop
      BEGIN
         IF @b_debug = 1
         BEGIN
            PRINT 'Storerkey=' + @cStorerkey +' ;InvoiceNo=' + @cInvoiceNo  + ' ;UserDefine10' + @cUserDefine10
         END
         IF @cUserDefine10 = ''
         BEGIN
            SET @cPrintFlag = 'N'
            SET @cDRCounterKey = ''

            SELECT @cDRCounterKey = Code
            FROM CodeLkUp WITH (NOLOCK)
            WHERE ListName = 'DR_NCOUNT'
            AND SHORT = @cStorerkey

            IF @cDRCounterKey = ''
            BEGIN
               SELECT @n_continue = 3
               SELECT @n_err = 63502  -- should assign new error code
               SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": No Setup for CodeLkUp.ListName = DR_NCOUNT. (isp_Delivery_Receipt03) "+@cstorerkey
            END

            IF @b_debug = 1
            BEGIN
               PRINT 'Check this: SELECT Code FROM Codelkup WITH (NOLOCK) WHERE ListName = ''DR_NCOUNT'' AND SHORT =N''' + dbo.fnc_RTrim(@cStorerkey) + ''''
            END

            IF @n_continue = 1 or @n_continue = 2
            BEGIN
               SELECT @b_success = 0

               EXECUTE nspg_GetKey
                        @cDRCounterKey,
                        10,
                        @cUserDefine10 OUTPUT,
                        @b_success     OUTPUT,
                        @n_err         OUTPUT,
                        @c_errmsg      OUTPUT

               IF @b_debug = 1
               BEGIN
                  PRINT ' GET UserDefine10 (DR)= ' + @cUserDefine10 + master.dbo.fnc_GetCharASCII(13)
               END

               IF @b_success <> 1
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @n_err = 63503  -- should assign new error code
                  SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Fail to Generate Userdeine10 . (isp_Delivery_Receipt03)"
               END
               ELSE
               BEGIN
                  UPDATE ORDERS
                  SET UserDefine10 = @cUserDefine10
                    , UserDefine07 = GETDATE()   -- Update DR Print Date 'added by fklim 07032007
                    , EditDate     = GETDATE()   -- KHLim01
                    , TrafficCop   = NULL
                  WHERE MBOLKey = @cMBOLKey
                  AND StorerKey = @cStorerKey
                  AND InvoiceNo = @cInvoiceNo
                  AND C_Company = @cC_Company

                  SELECT @n_err = @@ERROR

                  IF @n_err <> 0
                  BEGIN
                     SELECT @n_continue = 3
                     SELECT @n_err = 63504  -- should assign new error code
                     SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": UPDATE ORDERS Failed. (isp_Delivery_Receipt03)"
                  END
               END
            END  -- @n_continue = 1 or @n_continue = 2
         END
         ELSE
         BEGIN
            SET @cPrintFlag = 'Y'
         END

         INSERT INTO #TempFlag(PrintFlag, InvoiceNo, C_Company)
         VALUES(@cPrintFlag, @cInvoiceNo, @cC_Company)

         FETCH NEXT FROM CurOrderGroup INTO @cStorerkey, @cUserDefine10, @cC_Company, @cInvoiceNo
      END

      CLOSE CurOrderGroup
      DEALLOCATE CurOrderGroup
   END -- @nRecCnt > 0

   IF @b_debug = 1
   BEGIN
      SELECT * FROM #TempFlag
   END

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      SELECT
         PRINCIPAL.Company,
         STORER.SUSR1,
         ORDERS.UserDefine10,
         ORDERS.BuyerPO,
         MBOLDetail.InvoiceNo,
         ORDERS.ConsigneeKey,
         ORDERS.C_Company,
         ORDERS.C_Address1,
         ORDERS.C_Address2,
         MBOL.DepartureDate,
         SKU.Descr,
         ORDERDetail.SKU,
         ConsigneeSKU.ConsigneeSKU,
         ConsigneeSKU.CrossSKUQty,
         SUM(PickDetail.Qty) AS Qty,
         PACK.CaseCnt,
         STORER.StorerKey AS ConsigneeFor,
         @cPrintFlag AS PrintFlag
      FROM MBOLDetail WITH (NOLOCK)
         JOIN MBOL WITH (NOLOCK)
         ON MBOL.MBOLKey = MBOLDetail.MBOLKey
         JOIN ORDERS WITH (NOLOCK)
         ON ORDERS.OrderKey = MBOLDetail.OrderKey
         JOIN ORDERDetail WITH (NOLOCK)
         ON ORDERDetail.OrderKey = ORDERS.OrderKey
         JOIN STORER PRINCIPAL WITH (NOLOCK)
         ON PRINCIPAL.StorerKey = ORDERS.StorerKey
         JOIN STORER CONSIGNEE WITH (NOLOCK)
         ON CONSIGNEE.StorerKey = ORDERS.ConsigneeKey
         JOIN STORER STORER WITH (NOLOCK)
         ON STORER.StorerKey = CONSIGNEE.ConsigneeFor
         JOIN SKU WITH (NOLOCK)
         ON SKU.SKU = ORDERDetail.SKU
         JOIN PickDetail WITH (NOLOCK)
         ON PickDetail.ORDERKey = ORDERDetail.ORDERKey
         AND PickDetail.OrderLineNumber = ORDERDetail.OrderLineNumber
         JOIN PACK WITH (NOLOCK)
         ON PACK.PackKey = SKU.PackKey
         LEFT JOIN ConsigneeSKU WITH (NOLOCK)
         ON ConsigneeSKU.STORERKey = ORDERS.STORERKey
         AND ConsigneeSKU.ConsigneeKey = Consignee.ConsigneeFor
         AND ConsigneeSKU.SKU = ORDERDetail.SKU
         AND ConsigneeSKU.Active = 'Y'
      WHERE MBOLDetail.MBOLKey = @cMBOLKey
         AND MBOLDetail.InvoiceNo <> ''
      GROUP BY PRINCIPAL.Company,
         STORER.SUSR1,
         ORDERS.UserDefine10,
         ORDERS.BuyerPO,
         MBOLDetail.InvoiceNo,
         ORDERS.ConsigneeKey,
         ORDERS.C_Company,
         ORDERS.C_Address1,
         ORDERS.C_Address2,
         MBOL.DepartureDate,
         SKU.Descr,
         ORDERDetail.SKU,
         ConsigneeSKU.ConsigneeSKU,
         ConsigneeSKU.CrossSKUQty,
         PACK.CaseCnt,
         STORER.StorerKey
   END

   IF @n_continue=3  -- Error Occured - Process And Return
   BEGIN
      EXECUTE nsp_logerror @n_err, @c_errmsg, "isp_Delivery_Receipt03"
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
END /* main procedure */

GO