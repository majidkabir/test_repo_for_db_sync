SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/
/* Store Procedure: isp_GetPickSlipOrders76                              */
/* Creation Date: 5/12/2017                                              */
/* Copyright: IDS                                                        */
/* Written by: WLCHOOI                                                   */
/*                                                                       */
/* Purpose: WMS-3555 TW-LFPM 289 E-Com Packing List                      */
/*                                                                       */
/* Called By: r_dw_print_pickorder76                                     */
/*                                                                       */
/* PVCS Version: 1.1                                                     */
/*                                                                       */
/* Version: 7.0                                                          */
/*                                                                       */
/* Data Modifications:                                                   */
/*                                                                       */
/* Updates:                                                              */
/* Date         Author  Ver.  Purposes                                   */
/* 20-DEC-2017  Wan01   1.1   Fixed. Link PickHeader by Orderkey         */
/*                            To avoid gen pickheader for orderkey with  */
/*                            different pickzone                         */
/* 21-DEC-2017  CSCHONG  1.2  Add in autoscanin config (CS01)            */
/* 08-JAN-2018  CSCHONG  1.3  WMS-3706 add new field (CS02)              */
/* 23-MAR-2018  CSCHONG  1.4  WMS-4287 revised field logic (CS03)        */
/* 11-JAN-2019  Grick    1.5  INC0533457 - BEGIN,COMMMIT error           */
/* 16-AUG-2019  WLChooi  1.6  WMS-10275 - Fix bugs (WL01)                */
/* 08-NOV-2019  Leong    1.7  INC0910083 - Bug Fix.                      */
/*************************************************************************/

CREATE PROC [dbo].[isp_GetPickSlipOrders76] (@c_LoadKey NVARCHAR(10))
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_continue        INT
         , @n_StartTCnt       INT
         , @b_success         INT
         , @n_err             INT
         , @c_errmsg          NVARCHAR(255)
         , @n_Batch           INT
         , @c_pickheaderkey   NVARCHAR(10)
         , @n_Maxline         INT
         , @n_cntRec          INT
         , @c_getLoadKey      NVARCHAR(20)
         , @c_getOrdKey       NVARCHAR(20)
         , @c_AutoScanIn      NVARCHAR(10)     --CS01
         , @c_PickSlipNo      NVARCHAR(10)     --CS01
         , @c_Facility        NVARCHAR(5)      --CS01
         , @c_storerkey       NVARCHAR(15)     --CS01

   SET @n_Continue      = 1
   SET @n_StartTCnt     = @@TRANCOUNT
   SET @b_success       = 1
   SET @n_err           = 0
   SET @c_errmsg        = ''
   SET @n_Maxline       = 10
   SET @n_cntRec        = 1

   SET @n_Batch         = 0
   SET @c_pickheaderkey = ''

   --CS01 Start
   SET @c_Facility = ''
   SELECT @c_Facility = Facility
   FROM LOADPLAN WITH (NOLOCK)
   WHERE LoadKey = @c_LoadKey

   WHILE @@TRANCOUNT > 0
   BEGIN
      COMMIT TRAN
   END

   CREATE TABLE #TEMP_PICK
         ( PickSlipNo      NVARCHAR(10)  NULL
         , LoadKey         NVARCHAR(10)
         , AddDate         DATETIME      NULL
         , OrderKey        NVARCHAR(20)
         , ExternOrderkey  NVARCHAR(60)  NULL
         , Contact1        NVARCHAR(60)  NULL
         , Postcode        NVARCHAR(36)  NULL
         , Address1        NVARCHAR(200) NULL
         , Phone1          NVARCHAR(36)  NULL
         , Phone2          NVARCHAR(36)  NULL
         , OrderInfo01     NVARCHAR(60)  NULL
         , OrderInfo02     NVARCHAR(60)  NULL
         , OrderInfo03     NVARCHAR(60)  NULL
         , OrderInfo05     NVARCHAR(60)  NULL
         , Notes           NVARCHAR(255) NULL --WL01 Extend Length
         , Notes2          NVARCHAR(255) NULL --WL01 Extend Length
         , Loc             NVARCHAR(45)  NULL
         , OriginalQty     INT
         , OHUDef01        NVARCHAR(60)  NULL
         , UnitPrice       FLOAT         NULL
         , CarrierCharges  FLOAT         NULL
         , OtherCharges    FLOAT         NULL
         , InvoiceAmt      FLOAT         NULL
         , PrintedFlag     NVARCHAR(1)   NULL
         , SSTYLE          NVARCHAR(20)  NULL              --(CS03)
         , SBUSR           NVARCHAR(70)  NULL              --(CS03)
         )

   INSERT INTO #TEMP_PICK
         ( PickSlipNo
         , LoadKey
         , AddDate
         , OrderKey
         , ExternOrderkey
         , Contact1
         , Postcode
         , Address1
         , Phone1
         , Phone2
         , OrderInfo01
         , OrderInfo02
         , OrderInfo03
         , OrderInfo05
         , Notes
         , Notes2
         , Loc
         , OriginalQty
         , OHUDef01
         , UnitPrice
         , CarrierCharges
         , OtherCharges
         , InvoiceAmt
         , PrintedFlag
         , SSTYLE, SBUSR              --(CS03)
         )

   SELECT DISTINCT
         PickHeaderKey = ISNULL(RTRIM(PICKHEADER.PickHeaderKey), '')
       , LoadKey = @c_LoadKey
       , Orders.Adddate
       , Orders.OrderKey
       , ExternOrderKey = ISNULL(RTRIM(Orders.ExternOrderKey), '')
       , Contact1 = ISNULL(Orders.C_Contact1,'')
       , Postcode = ISNULL(RTRIM(Orders.C_Zip),'')
       , Address1 = (ISNULL(RTRIM(Orders.C_Address1),'') + ISNULL(RTRIM(Orders.C_Address2),'')
                    + ISNULL(RTRIM(Orders.C_Address3),'') + ISNULL(RTRIM(Orders.C_Address4),''))
       , Phone1 = ISNULL(Orders.C_Phone1,'')
       , Phone2 = ISNULL(Orders.C_Phone2,'')
       , OrderInfo01 = ISNULL(OrderInfo.OrderInfo01,'')
       , OrderInfo02 = CASE WHEN ISNULL(OrderInfo.OrderInfo02,'')='' THEN '0' ELSE ISNULL(OrderInfo.OrderInfo02,'') END
       , OrderInfo03 = CASE WHEN ISNULL(OrderInfo.OrderInfo03,'')='' THEN '0' ELSE ISNULL(OrderInfo.OrderInfo03,'') END
       , OrderInfo05 = CASE WHEN ISNULL(OrderInfo.OrderInfo05,'')='' THEN '0' ELSE ISNULL(OrderInfo.OrderInfo05,'') END
       , Notes = CASE WHEN ISNULL(OrderDetail.Notes,'') = '' THEN '' ELSE ISNULL(OrderDetail.Notes,'') END
       , Notes2 = ISNULL(OrderInfo.Notes2,'')
       , Loc = ISNULL(RTRIM(PickDetail.Loc),'')
       , OriginalQty = SUM(PickDetail.Qty) -- INC0910083
       , OHUDef01 = ISNULL(OrderDetail.Userdefine01,'')
       , Unitprice = CASE WHEN ISNULL(OrderDetail.Unitprice,'')='' THEN '0' ELSE ISNULL(OrderDetail.Unitprice,'') END
       , Carriercharges = CASE WHEN ISNULL(OrderInfo.Carriercharges,'')='' THEN '0' ELSE ISNULL(OrderInfo.Carriercharges,'') END
       , Othercharges = CASE WHEN ISNULL(OrderInfo.Othercharges,'')='' THEN '0' ELSE ISNULL(OrderInfo.Othercharges,'') END
       , InvoiceAmount = CASE WHEN ISNULL(Orders.InvoiceAmount,'')='' THEN '0' ELSE ISNULL(Orders.InvoiceAmount,'') END
       , PrintedFlag= CASE WHEN ISNULL(RTRIM(PICKHEADER.PickType), 'N') = '1' THEN 'Y' ELSE 'N' END
       , SStyle  = ISNULL(S.Style,'')                                       --(CS03)
       , SBUSR = ISNULL(RTRIM(LTRIM(S.BUSR1)),'') + '/' + ISNULL(RTRIM(LTRIM(S.BUSR2)),'')              --(CS03)
   FROM LoadplanDetail WITH (NOLOCK)
   JOIN Orders         WITH (NOLOCK) ON (Orders.Orderkey = LoadplanDetail.Orderkey)
   LEFT JOIN OrderInfo WITH (NOLOCK) ON (OrderInfo.OrderKey = Orders.OrderKey)
   JOIN OrderDetail    WITH (NOLOCK) ON (Orders.OrderKey = OrderDetail.OrderKey)
   JOIN PickDetail              WITH (NOLOCK) ON (PickDetail.OrderKey = OrderDetail.OrderKey)
                                              AND(PickDetail.OrderLineNumber = OrderDetail.OrderlineNumber)
   JOIN Loc            WITH (NOLOCK, INDEX (PKLOC)) ON (PickDetail.Loc = Loc.Loc)
   LEFT OUTER JOIN PICKHEADER   WITH (NOLOCK) ON (LoadplanDetail.Orderkey= PICKHEADER.Orderkey)          --(Wan01)
   JOIN SKU S WITH (NOLOCK) ON S.storerkey =  OrderDetail.Storerkey AND S.sku =OrderDetail.sku           --(CS03)
   WHERE LoadplanDetail.LoadKey = @c_LoadKey
      AND PickDetail.Status >= '0'
   GROUP BY ISNULL(RTRIM(PICKHEADER.PickHeaderKey), '')
            , Orders.Adddate
            , Orders.OrderKey
            , ISNULL(RTRIM(Orders.ExternOrderKey), '')
            , ISNULL(Orders.C_Contact1,'')
            , ISNULL(RTRIM(Orders.C_Zip),'')
            , (ISNULL(RTRIM(Orders.C_Address1),'') + ISNULL(RTRIM(Orders.C_Address2),'')
               + ISNULL(RTRIM(Orders.C_Address3),'') + ISNULL(RTRIM(Orders.C_Address4),''))
            , ISNULL(Orders.C_Phone1,'')
            , ISNULL(Orders.C_Phone2,'')
            , ISNULL(OrderInfo.OrderInfo01,'')
            , CASE WHEN ISNULL(OrderInfo.OrderInfo02,'')='' THEN '0' ELSE ISNULL(OrderInfo.OrderInfo02,'') END
            , CASE WHEN ISNULL(OrderInfo.OrderInfo03,'')='' THEN '0' ELSE ISNULL(OrderInfo.OrderInfo03,'') END
            , CASE WHEN ISNULL(OrderInfo.OrderInfo05,'')='' THEN '0' ELSE ISNULL(OrderInfo.OrderInfo05,'') END
            , CASE WHEN ISNULL(OrderDetail.Notes,'')='' THEN '' ELSE ISNULL(OrderDetail.Notes,'') END
            , ISNULL(OrderInfo.Notes2,'')
            , ISNULL(RTRIM(PickDetail.Loc),'')
          --, OrderDetail.OriginalQty
            , ISNULL(OrderDetail.Userdefine01,'')
            , CASE WHEN ISNULL(OrderDetail.Unitprice,'')='' THEN '0' ELSE ISNULL(OrderDetail.Unitprice,'') END
            , CASE WHEN ISNULL(OrderInfo.Carriercharges,'')='' THEN '0' ELSE ISNULL(OrderInfo.Carriercharges,'') END
            , CASE WHEN ISNULL(OrderInfo.Othercharges,'')='' THEN '0' ELSE ISNULL(OrderInfo.Othercharges,'') END
            , CASE WHEN ISNULL(Orders.InvoiceAmount,'')='' THEN '0' ELSE ISNULL(Orders.InvoiceAmount,'') END
            , CASE WHEN ISNULL(RTRIM(PICKHEADER.PickType), 'N') = '1' THEN 'Y' ELSE 'N' END
            , ISNULL(S.Style,'')                                         --(CS03)
            , ISNULL(RTRIM(LTRIM(S.BUSR1)),'') , ISNULL(RTRIM(LTRIM(S.BUSR2)),'')      --(CS03)

   BEGIN TRAN
   -- Uses PickType as a Printed Flag
   UPDATE PICKHEADER WITH (ROWLOCK)
   SET PickType = '1'
     , TrafficCop = NULL
   WHERE ExternOrderKey = @c_LoadKey
   AND   Zone = '3'

   SET @n_err = @@ERROR
   IF @n_err <> 0
   BEGIN
      SET @n_Continue = 3
      IF @@TRANCOUNT > 0
      BEGIN
         ROLLBACK TRAN
      END
   END
   ELSE
   BEGIN
      IF @@TRANCOUNT > 0
      BEGIN
         COMMIT TRAN
      END
   END

   SELECT @n_Batch = Count(DISTINCT OrderKey)
   FROM #TEMP_PICK
   WHERE (PickSlipNo IS NULL OR RTRIM(PickSlipNo) = '')

   IF @@ERROR <> 0
   BEGIN
      GOTO FAILURE
   END
   ELSE IF @n_Batch > 0
   BEGIN
      BEGIN TRAN
      EXECUTE nspg_GetKey 'PICKSLIP'
            , 9
            , @c_Pickheaderkey   OUTPUT
            , @b_success         OUTPUT
            , @n_err             OUTPUT
            , @c_errmsg          OUTPUT
            , 0
            , @n_Batch

      SELECT @n_err = @@ERROR
      IF @n_err = 0
      BEGIN
         WHILE @@TRANCOUNT > 0
         BEGIN
            COMMIT TRAN
         END
      END

      BEGIN TRAN
      INSERT INTO PICKHEADER (PickHeaderKey, OrderKey, ExternOrderKey, PickType, Zone, TrafficCop)
      SELECT 'P' + RIGHT ( '000000000' +
                           LTRIM(RTRIM( STR( CAST(@c_pickheaderkey AS INT) +
                           ( SELECT COUNT(DISTINCT orderkey)
                           FROM #TEMP_PICK as Rank
                           WHERE Rank.OrderKey < #TEMP_PICK.OrderKey
                           AND ISNULL(RTRIM(Rank.PickSlipNo),'') = '' )
                           ) -- str
                          ))--LTRIM & RTRIM
                        , 9)
               , OrderKey
               , LoadKey
               , '0'
               , '3'
               , ''
      FROM #TEMP_PICK
      WHERE ISNULL(RTRIM(PickSlipNo),'') = ''
      GROUP BY LoadKey, OrderKey

      SELECT @n_err = @@ERROR
      IF @n_err = 0
      BEGIN
         WHILE @@TRANCOUNT > 0
         BEGIN
            COMMIT TRAN
         END
      END

      UPDATE #TEMP_PICK
      SET   PickSlipNo = PICKHEADER.PickHeaderKey
      FROM  PICKHEADER (NOLOCK)
      WHERE PICKHEADER.ExternOrderKey = #TEMP_PICK.LoadKey
      AND   PICKHEADER.OrderKey = #TEMP_PICK.OrderKey
      AND   PICKHEADER.Zone = '3'
      AND   (#TEMP_PICK.PickSlipNo IS NULL OR RTRIM(#TEMP_PICK.PickSlipNo) = '')
   END

   DECLARE CUR_load CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT LoadKey,OrderKey,PickSlipNo
   FROM #TEMP_PICK
   WHERE LoadKey = @c_LoadKey

   OPEN CUR_load
   FETCH NEXT FROM CUR_load INTO @c_getLoadKey, @c_GetOrdkey, @c_PickSlipNo

   WHILE @@FETCH_STATUS <> -1
   BEGIN
      SET @c_storerkey = ''
      SELECT @c_storerkey = ORD.Storerkey
      FROM Orders ORD (NOLOCK)
      WHERE Orderkey = @c_getOrdKey

      SET @n_cntRec = 1

      SELECT @n_cntRec = COUNT(1)
      FROM #TEMP_PICK
      WHERE LoadKey = @c_getLoadKey
      AND OrderKey=@c_GetOrdkey

      SET @c_AutoScanIn = '0'
      EXEC nspGetRight
            @c_Facility   = @c_Facility
         ,  @c_StorerKey  = @c_StorerKey
         ,  @c_sku        = ''
         ,  @c_ConfigKey  = 'AutoScanIn'
         ,  @b_Success    = @b_Success    OUTPUT
         ,  @c_authority  = @c_AutoScanIn OUTPUT
         ,  @n_err        = @n_err        OUTPUT
         ,  @c_errmsg     = @c_errmsg     OUTPUT

      IF @b_Success = 0
      BEGIN
         SET @n_Continue = 3
         GOTO FAILURE
      END

      IF @c_AutoScanIn = '1'
      BEGIN
         IF NOT EXISTS (SELECT 1
                        FROM PICKINGINFO WITH (NOLOCK)
                        WHERE PickSlipNo = @c_PickSlipNo
                        )
         BEGIN
            BEGIN TRAN    --G01
            INSERT INTO PICKINGINFO  (PickSlipNo, ScanInDate, PickerID, ScanOutDate)
            VALUES (@c_PickSlipNo, GETDATE(), SUSER_NAME(), NULL)

            SET @n_err = @@ERROR
            IF @n_err <> 0
            BEGIN
               SET @n_Continue = 3
               GOTO FAILURE
            END
         END
      END

      WHILE @@TRANCOUNT > 0
      BEGIN
         COMMIT TRAN
      END

   WHILE @n_cntRec < @n_Maxline
   BEGIN
      INSERT INTO #TEMP_PICK
         ( LoadKey
         , OrderKey
         , OrderInfo01
         , OrderInfo02
         , OrderInfo03
         , OrderInfo05
         , OriginalQty
         , CarrierCharges
         , OtherCharges
         , InvoiceAmt
         , PrintedFlag
         )
         SELECT TOP 1
             LoadKey
           , OrderKey
           , OrderInfo01
           , OrderInfo02
           , OrderInfo03
           , OrderInfo05
           , 0
           , CarrierCharges
           , OtherCharges
           , InvoiceAmt
           , PrintedFlag
        FROM #TEMP_PICK
        WHERE LoadKey = @c_getLoadKey
        AND OrderKey=@c_GetOrdkey

        SET @n_cntRec = @n_cntRec + 1
   END

   FETCH NEXT FROM CUR_load INTO @c_getLoadKey, @c_GetOrdkey, @c_PickSlipNo
   END
   CLOSE CUR_load
   DEALLOCATE CUR_load

   GOTO SUCCESS

FAILURE:
   DELETE FROM #TEMP_PICK

SUCCESS:
   SELECT PickSlipNo
         , LoadKey
         , AddDate
         , OrderKey
         , ExternOrderkey
         , Contact1
         , Postcode
         , Address1
         , Phone1
         , Phone2
         , OrderInfo01
         , OrderInfo02
         , OrderInfo03
         , OrderInfo05
         , Notes
         , Notes2
         , Loc
         , OriginalQty
         , OHUDef01
         , UnitPrice
         , CarrierCharges
         , OtherCharges
         , InvoiceAmt
         , PrintedFlag
         , SSTYLE, SBUSR                 --(CS03)
   FROM #TEMP_PICK
   ORDER BY Orderkey
          , CASE WHEN Loc IS NULL THEN 1 ELSE 0 END

   DROP TABLE #TEMP_PICK

   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END
END

GO