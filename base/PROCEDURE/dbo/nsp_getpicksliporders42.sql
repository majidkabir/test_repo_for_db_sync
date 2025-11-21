SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nsp_GetPickSlipOrders42                            */
/* Creation Date: 08/09/2011                                            */
/* Copyright: IDS                                                       */
/* Written by: YTWan                                                    */
/*                                                                      */
/* Purpose: SOS#225214:Perry Ellis Pickslip                             */
/*        : Copy from nsp_GetPickSlipOrders42 to modify                 */
/* Called By: r_dw_print_pickorder42                                    */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver   Purposes                                  */
/* 13-Feb-2012  Leong   1.1   SOS# 234891 - Prevent Pickslip number not */
/*                                          tally with nCounter table.  */
/************************************************************************/
CREATE PROC [dbo].[nsp_GetPickSlipOrders42] (@c_loadkey NVARCHAR(10))
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_pickheaderkey      NVARCHAR(10),
           @n_continue           int,
           @c_errmsg             NVARCHAR(255),
           @b_success            int,
           @n_err                int,
           @n_pickslips_required int

   SELECT ( SELECT PICKHEADERKEY FROM PICKHEADER (NOLOCK)
             WHERE ExternOrderKey = @c_LoadKey
             AND OrderKey = ORDERS.OrderKey
             AND ZONE = 'D') AS Pickslipno,
           ORDERS.Billtokey,
           ORDERS.B_Company,
           ORDERS.B_Address1,
           ORDERS.B_Address2,
           ISNULL(ORDERS.B_City,'') AS B_City,
           ISNULL(ORDERS.B_State,'') AS B_State,
           ISNULL(ORDERS.B_Zip,'') AS B_Zip,
           ORDERS.Consigneekey,
           ORDERS.C_Company,
           ORDERS.C_Address1,
           ORDERS.C_Address2,
           ISNULL(ORDERS.C_City,'') AS C_City,
           ISNULL(ORDERS.C_State,'') AS C_State,
           ISNULL(ORDERS.C_Zip,'') AS C_Zip,
           ORDERS.Externorderkey,
           ORDERS.Deliverydate,
           ORDERS.C_fax2,
           CASE WHEN STORER.Susr5 = 'HIDEACCNO' THEN RTRIM(STORER.Susr5) ELSE ORDERS.M_Fax1 END AS M_Fax1, --NJOW03
           --ORDERS.M_Fax1,
           ORDERS.Buyerpo,
           ORDERS.Invoiceno,
           ORDERS.Orderkey,
           LOADPLAN.Loadkey,
           PICKDETAIL.Loc,
           SKU.Style,
           SKU.Color,
           SKU.Size,
           SKU.Busr1,
           SKU.Busr8,                  --(Kc01)
           SUM(PICKDETAIL.Qty) AS Qty,
           ORDERDETAIL.Unitprice,
           ORDERDETAIL.Tax01,
           ORDERDETAIL.Tax02,
           ORDERDETAIL.Extendedprice,
           (SUM(PICKDETAIL.Qty) * ORDERDETAIL.Unitprice) + ORDERDETAIL.Tax01 - ORDERDETAIL.Tax02 + ORDERDETAIL.Extendedprice AS Amount,
           ORDERDETAIL.Sku,
           ORDERDETAIL.Userdefine01 AS ODUserdefine01,
           ORDERDETAIL.Userdefine02 AS ODUserdefine02,
           ORDERDETAIL.Userdefine05 AS ODUserdefine05,
           ORDERS.Userdefine10 AS OUserdefine10,
           ORDERS.Invoiceamount,
           ISNULL(SUBSTRING(ORDERS.Notes,1,250),'') AS Notes1a,
           ISNULL(SUBSTRING(ORDERS.Notes,251,250),'') AS Notes1b,
           ISNULL(SUBSTRING(ORDERS.Notes,501,250),'') AS Notes1c,
           ISNULL(SUBSTRING(ORDERS.Notes,751,250),'') AS Notes1d,
           ISNULL(SUBSTRING(ORDERS.Notes2,1,250),'') AS Notes2a,
           ISNULL(SUBSTRING(ORDERS.Notes2,251,250),'') AS Notes2b,
           ISNULL(SUBSTRING(ORDERS.Notes2,501,250),'') AS Notes2c,
           ISNULL(SUBSTRING(ORDERS.Notes2,751,250),'') AS Notes2d,
           STORER.Company,
           FACILITY.Descr,
           FACILITY.Userdefine01 AS FUserdefine01,
           FACILITY.Userdefine03 AS FUserdefine03,
           RTRIM(LEFT(FACILITY.Userdefine04,5))+'-'+RTRIM(LTRIM(RIGHT(FACILITY.Userdefine04,4))) AS FUSERDEFINE45,
           suser_sname() AS UserName,
           ISNULL((SELECT Distinct 'Y' FROM PickHeader WITH (NOLOCK) WHERE ExternOrderKey = @c_Loadkey AND  Zone = 'D')
                  , 'N') AS PrintedFlag,
           ORDERS.Pokey,
           LOC.Putawayzone,
           LOC.Logicallocation,
           ORDERDETAIL.Userdefine06 AS ODUserdefine06,
           ISNULL(STORER.Address1,'') AS Address1,
           ISNULL(STORER.Address2,'') AS Address2,
           ISNULL(STORER.City,'') AS City,
           ISNULL(STORER.State,'') AS State,
           ISNULL(STORER.Zip,'') AS Zip,
           ISNULL(STORER.Phone1,'') AS Phone1,
           ISNULL(STORER.Fax1,'') AS Fax1,
           ORDERS.B_Contact1,
           ORDERS.C_Contact1,
           ORDERDETAIL.ManufacturerSku,
           ORDERS.DeliveryNote AS ODeliveryNote,
           CONVERT(NVARCHAR(255),ISNULL(STORER.Notes1,'')) AS Remarks,
           ISNULL(RTRIM(SKU.DESCR),'') SKUDESCR,
           STORER.Susr4,
           MIN(ORDERDETAIL.Orderlinenumber) AS Orderlinenumber
   INTO #TEMP_PICK
   FROM LOADPLAN (NOLOCK)
   JOIN LOADPLANDETAIL (NOLOCK) ON (LOADPLAN.Loadkey = LOADPLANDETAIL.Loadkey)
   JOIN ORDERS (NOLOCK) ON (LOADPLANDETAIL.Orderkey = ORDERS.Orderkey)
   JOIN ORDERDETAIL (NOLOCK) ON (ORDERS.Orderkey = ORDERDETAIL.Orderkey)
   JOIN FACILITY (NOLOCK) ON (ORDERS.Facility = FACILITY.Facility)
   JOIN STORER (NOLOCK) ON (ORDERS.Storerkey = STORER.Storerkey)
   JOIN SKU (NOLOCK) ON (ORDERDETAIL.Storerkey = SKU.Storerkey
                       AND ORDERDETAIL.Sku = SKU.Sku)
   JOIN PICKDETAIL (NOLOCK) ON (ORDERDETAIL.Orderkey = PICKDETAIL.Orderkey
                              AND ORDERDETAIL.Orderlinenumber = PICKDETAIL.Orderlinenumber)
   JOIN LOC (NOLOCK) ON (PICKDETAIL.Loc = LOC.Loc)
   WHERE LOADPLAN.Loadkey = @c_loadkey
   GROUP BY ORDERS.Billtokey,
        ORDERS.B_Company,
        ORDERS.B_Address1,
        ORDERS.B_Address2,
        ISNULL(ORDERS.B_City,''),
        ISNULL(ORDERS.B_State,''),
        ISNULL(ORDERS.B_Zip,''),
        ORDERS.Consigneekey,
        ORDERS.C_Company,
        ORDERS.C_Address1,
        ORDERS.C_Address2,
        ISNULL(ORDERS.C_City,''),
        ISNULL(ORDERS.C_State,''),
        ISNULL(ORDERS.C_Zip,''),
        ORDERS.Externorderkey,
        ORDERS.Deliverydate,
        ORDERS.C_fax2,
        CASE WHEN STORER.Susr5 = 'HIDEACCNO' THEN RTRIM(STORER.Susr5) ELSE ORDERS.M_Fax1 END, --NJOW03
        --ORDERS.M_Fax1,
        ORDERS.Buyerpo,
        ORDERS.Invoiceno,
        ORDERS.Orderkey,
        LOADPLAN.Loadkey,
        PICKDETAIL.Loc,
        SKU.Style,
        SKU.Color,
        SKU.Size,
        SKU.Busr1,
        SKU.Busr8,
        ORDERDETAIL.Unitprice,
        ORDERDETAIL.Tax01,
        ORDERDETAIL.Tax02,
        ORDERDETAIL.Extendedprice,
        ORDERDETAIL.Sku,
        ORDERDETAIL.Userdefine01,
        ORDERDETAIL.Userdefine02,
        ORDERDETAIL.Userdefine05,
        ORDERS.Userdefine10,
        ORDERS.Invoiceamount,
        ISNULL(SUBSTRING(ORDERS.Notes,1,250),''),
        ISNULL(SUBSTRING(ORDERS.Notes,251,250),''),
        ISNULL(SUBSTRING(ORDERS.Notes,501,250),''),
        ISNULL(SUBSTRING(ORDERS.Notes,751,250),''),
        ISNULL(SUBSTRING(ORDERS.Notes2,1,250),''),
        ISNULL(SUBSTRING(ORDERS.Notes2,251,250),''),
        ISNULL(SUBSTRING(ORDERS.Notes2,501,250),''),
        ISNULL(SUBSTRING(ORDERS.Notes2,751,250),''),
        STORER.Company,
        FACILITY.Descr,
        FACILITY.Userdefine01,
        FACILITY.Userdefine03,
        RTRIM(LEFT(FACILITY.Userdefine04,5))+'-'+RTRIM(LTRIM(RIGHT(FACILITY.Userdefine04,4))),
        ORDERS.Pokey,
        LOC.Putawayzone,
        LOC.Logicallocation,
        ORDERDETAIL.Userdefine06,
        ISNULL(STORER.Address1,''),
        ISNULL(STORER.Address2,''),
        ISNULL(STORER.City,''),
        ISNULL(STORER.State,''),
        ISNULL(STORER.Zip,''),
        ISNULL(STORER.Phone1,''),
        ISNULL(STORER.Fax1,''),
        ORDERS.B_Contact1,
        ORDERS.C_Contact1,
        ORDERDETAIL.ManufacturerSku,
        ORDERS.DeliveryNote,
        CONVERT(NVARCHAR(255),ISNULL(STORER.Notes1,'')),
        ISNULL(RTRIM(SKU.DESCR),''),
        STORER.Susr4

   SELECT Orderkey, MIN(OrderLineNumber) AS OrderLineNumber
   INTO #FIRSTLINE
   FROM #TEMP_PICK
   GROUP BY Orderkey

   SELECT TP.Orderkey, CASE WHEN TP.Susr4 = 'PRINTBYSTYLE' THEN MIN(TP.Style) ELSE MIN(TP.LogicalLocation) END AS SEQ1,
             CASE WHEN TP.Susr4 = 'PRINTBYSTYLE' THEN MIN(TP.LogicalLocation) ELSE MIN(TP.Style) END AS SEQ2
   INTO #SORT
   FROM #TEMP_PICK TP
   JOIN #FIRSTLINE ON TP.Orderkey = #FIRSTLINE.Orderkey AND TP.OrderLineNumber = #FIRSTLINE.OrderLineNumber
   GROUP BY TP.Orderkey, TP.Susr4


   BEGIN TRAN
   -- Uses PickType as a Printed Flag

   UPDATE PickHeader WITH (ROWLOCK)
      SET PickType = '1', TrafficCop = NULL
    WHERE ExternOrderKey = @c_LoadKey
      AND Zone = 'D'

   SET @n_err = @@ERROR

   IF @n_err <> 0
   BEGIN
      SET @n_continue = 3
      IF @@TRANCOUNT >= 1
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
      ELSE
      BEGIN
         SET @n_continue = 3
         ROLLBACK TRAN
      END
   END

   SELECT @n_pickslips_required = COUNT(DISTINCT OrderKey)
   FROM #TEMP_PICK
   WHERE PickSlipNo IS NULL

   IF @@ERROR <> 0
   BEGIN
      GOTO FAILURE
   END
   ELSE IF @n_pickslips_required > 0
   BEGIN
      EXECUTE nspg_GetKey 'PICKSLIP', 9, @c_pickheaderkey OUTPUT, @b_success OUTPUT, @n_err  OUTPUT, @c_errmsg OUTPUT,
              0, @n_pickslips_required

      INSERT INTO PICKHEADER (PickHeaderKey,    OrderKey, ExternOrderKey, PickType, Zone, TrafficCop)
      SELECT 'P' + RIGHT ( REPLICATE ('0', 9) +
                      LTRIM( RTRIM(
                     STR(
                       CAST(@c_pickheaderkey AS INT) + ( SELECT count(DISTINCT orderkey)
                                                          FROM #TEMP_PICK AS Rank
                                                          WHERE Rank.OrderKey < T.OrderKey 
                                                          AND ISNULL(RTRIM(Rank.PickSlipNo),'') = '' ) -- SOS# 234891
           )))
                         , 9)
            ,T.OrderKey
            ,T.LoadKey
            ,'0'
            ,'D'
            ,''
      FROM #TEMP_PICK T
      JOIN #SORT S ON (T.Orderkey = S.Orderkey)
      WHERE T.PickSlipNo IS NULL
      GROUP By T.LoadKey, S.Seq1, S.Seq2, T.Pokey, T.OrderKey
      ORDER BY T.Loadkey, S.seq1, S.Seq2, T.Pokey, T.Orderkey

      UPDATE #TEMP_PICK
       SET PickSlipNo = PICKHEADER.PickHeaderKey
        FROM PICKHEADER WITH (NOLOCK)
       WHERE PICKHEADER.ExternOrderKey = #TEMP_PICK.LoadKey
         AND PICKHEADER.OrderKey = #TEMP_PICK.OrderKey
         AND PICKHEADER.Zone = 'D'
         AND #TEMP_PICK.PickSlipNo IS NULL
   END
   GOTO SUCCESS

   FAILURE:
      DELETE FROM #TEMP_PICK
      DELETE FROM #SQTY
   SUCCESS:

      SELECT #TEMP_PICK.* INTO #TEMP_PICK1
      FROM #TEMP_PICK WHERE 1=2

      Alter table #TEMP_PICK1 ADD Seq Int IDENTITY(1,1)


      INSERT INTO #TEMP_PICK1
      SELECT #TEMP_PICK.*
      FROM #SORT
      JOIN #TEMP_PICK on (#SORT.Orderkey = #TEMP_PICK.Orderkey)

      ORDER BY #TEMP_PICK.Loadkey,
                  #SORT.Seq1,
                  #SORT.Seq2,
                  #TEMP_PICK.Pokey,
              #TEMP_PICK.Orderkey,
                  CASE WHEN #TEMP_PICK.Susr4 = 'PRINTBYSTYLE' THEN
                       RTRIM(ISNULL(#TEMP_PICK.Style,''))+#TEMP_PICK.LogicalLocation ELSE RTRIM(#TEMP_PICK.LogicalLocation)+ISNULL(#TEMP_PICK.Style,'') END,
              #TEMP_PICK.Color,
              #TEMP_PICK.BUSR8,
              #TEMP_PICK.Size

      SELECT  Pickslipno,
              Billtokey,
              B_Company,
              B_Address1,
              B_Address2,
              B_City,
              B_State,
              B_Zip,
              Consigneekey,
              C_Company,
              C_Address1,
              C_Address2,
              C_City,
              C_State,
              C_Zip,
              Externorderkey,
              Deliverydate,
              C_fax2,
              M_Fax1,
              Buyerpo,
              Invoiceno,
              Orderkey,
              Loadkey,
              Loc,
              Style,
              Color,
              Size,
              Busr1,
              Qty,
              Unitprice,
              Tax01,
              Tax02,
              Extendedprice,
              Amount,
              Sku,
              ODUserdefine02,
              ODUserdefine05,
              OUserdefine10,
              Invoiceamount,
              Notes1a,
              Notes1b,
              Notes1c,
              Notes1d,
              Notes2a,
              Notes2b,
              Notes2c,
              Notes2d,
              Company,
              Descr,
              FUserdefine01,
              FUserdefine03,
              FUSERDEFINE45,
              UserName,
              PrintedFlag,
              Pokey,
              Putawayzone,
              Logicallocation,
              ODUserdefine06,
              Address1,
              Address2,
              City,
              State,
              Zip,
              Phone1,
              Fax1,
              B_Contact1,
              C_Contact1,
              ManufacturerSku,
              ODeliveryNote,
              Remarks,
              SKUDESCR
      FROM #TEMP_PICK1
      ORDER BY Loadkey
            ,  Orderkey
            ,  Style
            ,  Color
            ,  Busr8
            ,  SKU


      DROP Table #TEMP_PICK
      DROP Table #TEMP_PICK1
      DROP Table #FIRSTLINE
      DROP Table #SORT
END

GO