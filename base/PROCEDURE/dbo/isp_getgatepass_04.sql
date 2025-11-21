SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure:  isp_GetGatePass_04                                 */
/* Creation Date: 2021-05-24                                            */
/* Copyright: LFL                                                       */
/* Written by: CSHONG                                                   */
/*                                                                      */
/* Purpose: WMS-17064 - PH_Young Living - MBOL                          */
/*                                                                      */
/* Input Parameters:  @c_mbolkey  - MBOL Key                            */
/*                                                                      */
/* Output Parameters:  None                                             */
/*                                                                      */
/* Return Status:  None                                                 */
/*                                                                      */
/* Usage:  Used for report dw = r_dw_gatepass_04                        */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By:  RMC from MBOL                                            */
/*                                                                      */
/* GitLab Version: 1.3                                                  */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 05-Aug-2021  LZG       1.1   JSM-13140-Removed ShipperKey join (ZG01)*/
/* 19-Aug-2021  Leong     1.2   JSM-16113-Update with TrafficCop.       */
/************************************************************************/

CREATE PROC [dbo].[isp_GetGatePass_04] (@c_mbolkey NVARCHAR(10))
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_continue            INT,
           @c_errmsg              NVARCHAR(255),
           @b_success             INT,
           @n_err                 INT,
           @n_cnt                 INT,
           @c_OtherReference      NVARCHAR(30),
           @c_facility            NVARCHAR(5),
           @c_keyname             NVARCHAR(30),
           @c_printflag           NVARCHAR(1),
           @c_Containerkey        NVARCHAR(20),
           @c_Mode                NVARCHAR(20),
           @c_DRGenerated         NVARCHAR(1) = 'N',
           @c_GetOtherReference   NVARCHAR(30)

   SELECT @n_continue = 1, @n_err = 0, @c_errmsg = '', @b_success = 1, @n_cnt = 0, @c_printflag = 'Y'


   CREATE TABLE [#TMP_ALLMBOL] (
      MBOLKey           [NVARCHAR] (10) NULL,
      Containerkey      [NVARCHAR] (20) NULL,
      Mode              [NVARCHAR] (20) NULL
   )

   SELECT @c_Containerkey = MBOL.UserDefine05
   FROM MBOL (NOLOCK)
   WHERE MBOL.MbolKey = @c_mbolkey

   IF ISNULL(@c_Containerkey,'') = ''
   BEGIN
      INSERT INTO #TMP_ALLMBOL (MBOLKey, Containerkey, Mode)
      SELECT @c_MBOLkey, '', 'By MBOL'
   END
   ELSE
   BEGIN
      INSERT INTO #TMP_ALLMBOL (MBOLKey, Containerkey, Mode)   --Find all MBOL under same Userdefine05 (Containerkey)
      SELECT DISTINCT MBOL.MBOLKey, @c_Containerkey, 'By Containerkey'
      FROM MBOL (NOLOCK)
      JOIN MBOLDETAIL (NOLOCK) ON MBOL.MbolKey = MBOLDETAIL.MbolKey
      JOIN ORDERS (NOLOCK) ON ORDERS.OrderKey = MBOLDETAIL.OrderKey
      WHERE MBOL.UserDefine05 = @c_Containerkey
   END

   DECLARE CUR_LOOP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT MBOLKey, Mode
   FROM #TMP_ALLMBOL

   OPEN CUR_LOOP

   FETCH NEXT FROM CUR_LOOP INTO @c_MBOLkey, @c_Mode

   WHILE @@FETCH_STATUS <> -1
   BEGIN
      IF @c_DRGenerated = 'Y'
      BEGIN
         UPDATE MBOL WITH (ROWLOCK)
         SET OtherReference = @c_GetOtherReference
           , EditDate   = GETDATE()
           , TrafficCop = NULL  -- JSM-16113
         WHERE MbolKey = @c_mbolkey
      END

      SELECT @c_OtherReference = MBOL.OtherReference, @c_facility = MBOL.Facility
      FROM MBOL (NOLOCK)
      WHERE Mbolkey = @c_mbolkey

      SELECT @n_cnt = @@ROWCOUNT

      IF ISNULL(RTRIM(@c_OtherReference),'') = '' AND @n_cnt > 0 AND @c_DRGenerated = 'N'
      BEGIN
         SELECT @c_printflag = 'N'

         SELECT @c_keyname = Code
         FROM CODELKUP (NOLOCK)
         WHERE ListName = 'GP_NCOUNT'
         AND Short = @c_facility

         IF ISNULL(RTRIM(@c_keyname),'') = ''
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 62313
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': CODELKUP LISTNAME GP_NCOUNT Retrieving Failed For Facility '+RTRIM(@c_facility)+' (isp_GetGatePass_04)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
         END

         IF @n_continue = 1 or @n_continue = 2
         BEGIN
            EXECUTE nspg_GetKey
                  @c_keyname,
                  10,
                  @c_OtherReference OUTPUT,
                  @b_success      OUTPUT,
                  @n_err          OUTPUT,
                  @c_errmsg       OUTPUT

            IF @n_err <> 0
            BEGIN
               SELECT @n_continue = 3
            END
            ELSE
            BEGIN
               SET @c_GetOtherReference = @c_OtherReference

               --BEGIN TRAN
               UPDATE MBOL WITH (ROWLOCK)
               SET OtherReference = @c_OtherReference,
                   EditDate   = GETDATE(),
                   TrafficCop = NULL
               WHERE Mbolkey = @c_mbolkey

               SELECT @n_err = @@ERROR
               IF @n_err <> 0
               --BEGIN
                  --WHILE @@TRANCOUNT > 0
                        --COMMIT TRAN
               --END
               --ELSE
               BEGIN
                  --ROLLBACK TRAN
                  SELECT @n_continue = 3
                  SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 62314
                  SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update MBOL Failed. (isp_GetGatePass_04)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
               END
            END
         END

         IF @n_continue IN (1,2) AND @c_Mode = 'By Containerkey'
         BEGIN
            SET @c_DRGenerated = 'Y'
         END
      END
      FETCH NEXT FROM CUR_LOOP INTO @c_MBOLkey, @c_Mode
   END
   CLOSE CUR_LOOP
   DEALLOCATE CUR_LOOP


   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      SELECT   MBOL.mbolkey
             , MAX(MBOL.facility)
             , FACILITY.descr
             , MAX(MBOL.carrieragent)
             , HAULER.Company
             , MAX(MBOL.Vehicle_Type) AS trucktype
             , MAX(MBOL.vessel) AS truckno
             , MAX(MBOL.drivername)
             , MAX(MBOL.departuredate)
             , ''
             , ''
             , MAX(ORDERS.[Route])
             , MAX(ROUTEMASTER.Descr)
             , MAX(MBOL.OtherReference)
             , MAX(MBOL.UserDefine04)
             , MAX(MBOL.SealNo)
             , MAX(MBOL.ContainerNo)
             , ''
             , ''
             , MAX(MBOL.editwho)
             , ROUND(SUM(CASE WHEN PACK.casecnt > 0 THEN PICKDETAIL.qty / PACK.casecnt ELSE 0 END),2) AS totalcase
             , ROUND(SUM(CASE WHEN PACK.casecnt > 0 THEN ROUND(SKU.STDGROSSWGT * PACK.CaseCnt,3) * (PICKDETAIL.qty / PACK.casecnt) ELSE 0 END),2) AS grossweight
             , @c_printflag AS PrintFlag
             , ROUND(SUM(PICKDETAIL.qty * SKU.Stdcube),4) AS CBM
             , ''   --ORDERS.Loadkey
             , MAX(LEFT(ISNULL(MBOL.Remarks,''),250)) AS Remark1
             , MAX(SUBSTRING(ISNULL(MBOL.Remarks,''),251,250)) AS Remark2
             , ''
             , CASE WHEN ISNULL(CLR.Code,'') <> '' THEN 'Y' ELSE 'N' END AS HideExternLoadkey
             , SUM(PICKDETAIL.qty) AS totalEaches
             , MAX(TN.TTLCTN)
             , CASE WHEN ISNULL(ORDERS.Salesman,'') = '' THEN 'STO' ELSE ORDERS.Salesman END
             , @c_Containerkey AS Containerkey
             , MBOL.externmbolkey
      FROM PICKDETAIL (NOLOCK)
      INNER JOIN ORDERDETAIL (NOLOCK) ON (PICKDETAIL.orderkey  = ORDERDETAIL.Orderkey
                                            AND PICKDETAIL.orderlinenumber = ORDERDETAIL.orderlinenumber)
      INNER JOIN ORDERS (NOLOCK) ON (PICKDETAIL.orderkey = ORDERS.orderkey)
      INNER JOIN SKU (NOLOCK) ON (PICKDETAIL.storerkey = SKU.storerkey
                                    AND PICKDETAIL.Sku = SKU.Sku)
      INNER JOIN PACK (NOLOCK) ON (PICKDETAIL.packkey = PACK.packkey)
      INNER JOIN MBOLDETAIL(NOLOCK) ON  (ORDERDETAIL.Mbolkey =  MBOLDETAIL.mbolkey
                                     AND ORDERDETAIL.loadkey = MBOLDETAIL.Loadkey
                                     AND ORDERDETAIL.orderkey = MBOLDETAIL.OrderKey)
      INNER JOIN MBOL (NOLOCK) ON (MBOLDETAIL.Mbolkey = MBOL.mbolkey)
      LEFT JOIN ROUTEMASTER (NOLOCK) ON (ORDERS.route = ROUTEMASTER.route)
      -- LEFT OUTER JOIN STORER HAULER (NOLOCK) ON ('3'+MBOL.Carrierkey = LEFT(HAULER.Type,1)+HAULER.StorerKey)
      LEFT OUTER JOIN STORER HAULER (NOLOCK) ON (MBOL.Carrierkey = HAULER.StorerKey AND LEFT(HAULER.Type,1) = '3')
      LEFT OUTER JOIN Codelkup CLR (NOLOCK) ON (ORDERS.Storerkey = CLR.Storerkey AND CLR.Code = 'HIDEEXTERNLOADKEY'
                                             AND CLR.Listname = 'REPORTCFG' AND CLR.Long = 'r_dw_gatepass_04' AND ISNULL(CLR.Short,'') <> 'N')
      INNER JOIN FACILITY (NOLOCK) ON (MBOL.facility = FACILITY.facility)
      JOIN LOADPLAN WITH (NOLOCK) ON LOADPLAN.loadkey = ORDERDETAIL.loadkey
      JOIN lotattribute LOTT WITH (NOLOCK) ON LOTT.lot=PICKDETAIL.Lot AND LOTT.sku = PICKDETAIL.sku AND LOTT.Storerkey = PICKDETAIL.Storerkey
      JOIN #TMP_ALLMBOL t ON t.MBOLKey = MBOL.MBOLKey AND MBOL.[Status] = '9'
      --WHERE ORDERDETAIL.mbolkey = @c_mbolkey AND MBOL.status = '9'
      CROSS APPLY (SELECT COUNT(DISTINCT OH.TrackingNo) AS TTLCTN
                   FROM ORDERS OH (NOLOCK)
                   WHERE OH.MBOLKey = MBOL.MBOLKey
                   AND OH.Salesman = ORDERS.Salesman
                   --AND OH.Shipperkey = ORDERS.Shipperkey     -- ZG01
                   ) AS TN
      GROUP BY MBOL.Mbolkey
             --, MBOL.facility
             , FACILITY.descr
             --, MBOL.carrieragent
             , HAULER.Company
             --, MBOL.vesselqualifier
             --, MBOL.vessel
             --, MBOL.drivername
             --, MBOL.departuredate
             --, ORDERS.route
             --, ROUTEMASTER.Descr
             --, MBOL.UserDefine04
             --, MBOL.SealNo
             --, MBOL.ContainerNo
             --, MBOL.editwho
             --, ORDERS.Loadkey
             --, LEFT(ISNULL(MBOL.Remarks,''),250)
             --, SUBSTRING(ISNULL(MBOL.Remarks,''),251,250)
             , CASE WHEN ISNULL(CLR.Code,'') <> '' THEN 'Y' ELSE 'N' END
             , CASE WHEN ISNULL(ORDERS.Salesman,'') = '' THEN 'STO' ELSE ORDERS.Salesman END
             , MBOL.externmbolkey
   END

   IF @n_continue = 3
   BEGIN
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_GetGatePass_04'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
END

GO