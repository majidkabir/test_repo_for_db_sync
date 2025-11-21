SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: isp_RPT_LP_PLISTC_001_2                               */
/* Creation Date: 20-JAN-2022                                              */
/* Copyright: LFL                                                          */
/* Written by: Harshitha                                                   */
/*                                                                         */
/* Purpose: WMS-18807                                                      */
/*                                                                         */
/* Called By: RPT_LP_PLISTC_001                                            */
/*                                                                         */
/* GitLab Version: 1.0                                                     */
/*                                                                         */
/* Version: 1.0                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author      Ver. Purposes                                  */
/* 24-Jan-2022  WLChooi     1.0  DevOps Combine Script                     */
/***************************************************************************/

CREATE PROC [dbo].[isp_RPT_LP_PLISTC_001_2]
      @c_LoadKey        NVARCHAR(10)
    , @c_PreGenRptData  NVARCHAR(10)
 AS
 BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @d_date_start      DATETIME,
           @d_date_end        DATETIME,
           @c_sku             NVARCHAR(20),
           @c_storerkey       NVARCHAR(15),
           @c_lot             NVARCHAR(10),
           @c_uom             NVARCHAR(10),
           @c_Route           NVARCHAR(10),
           @c_Exe_String      NVARCHAR(60),
           @n_Qty             INT,
           @c_Pack            NVARCHAR(10),
           @n_CaseCnt         INT
   DECLARE @c_CurrOrderKey    NVARCHAR(10),
           @c_MBOLKey         NVARCHAR(10),
           @c_FirstTime       NVARCHAR(1),
           @c_PrintedFlag     NVARCHAR(1),
           @n_err             INT,
           @n_continue        INT,
           @c_PickHeaderKey   NVARCHAR(10),
           @b_success         INT,
           @c_errmsg          NVARCHAR(255),
           @n_StartTranCnt    INT

   SELECT @n_StartTranCnt=@@TRANCOUNT, @n_continue = 1
   -- Use Zone as a UOM Picked 1 - Pallet, 2 - Case, 6 - Each, 7 - Consolidated pick list , 8 - By Order

   BEGIN TRAN

   SELECT @c_PickHeaderKey = ''
   SELECT @c_PickHeaderKey = PickHeaderKey
   FROM  PickHeader (NOLOCK)
   WHERE ExternOrderKey = @c_LoadKey
   AND   Zone = '7'

   IF dbo.fnc_RTrim(@c_PickHeaderKey) IS NOT NULL AND dbo.fnc_RTrim(@c_PickHeaderKey) <> ''
   BEGIN
      SELECT @c_FirstTime = 'N'
      SELECT @c_PrintedFlag = 'Y'
   END
   ELSE
   BEGIN
      SELECT @c_FirstTime = 'Y'
      SELECT @c_PrintedFlag = 'N'
   END -- Record Not Exists

   -- Uses PickType as a PrINTed Flag
   IF (@n_continue = 1 or @n_continue = 2) AND @c_PreGenRptData = 'Y'
   BEGIN
      IF @c_FirstTime = 'Y'
      BEGIN
         SELECT @c_PickHeaderKey = SPACE(10)
         SELECT @b_success = 0

         EXECUTE nspg_GetKey
           'PICKSLIP',
           9,
           @c_PickHeaderKey    OUTPUT,
           @b_success       OUTPUT,
           @n_err           OUTPUT,
           @c_errmsg        OUTPUT

         IF @b_success <> 1
         BEGIN
            SELECT @n_continue = 3
            GOTO EXIT_SP
          END

         IF @n_continue = 1 or @n_continue = 2
         BEGIN
            SELECT @c_PickHeaderKey = 'P' + @c_PickHeaderKey
            INSERT INTO PICKHEADER (PickHeaderKey,  ExternOrderKey, PickType, Zone, TrafficCop)
                            VALUES (@c_PickHeaderKey, @c_LoadKey,      '0',  '7', '')
         END

         -- Do Auto Scan-in when only 1 storer found and configkey is setup
         IF @n_continue = 1 or @n_continue = 2
         BEGIN
            DECLARE @nCnt   INT,
                    @cStorerKey NVARCHAR(15)

            IF ( SELECT COUNT(DISTINCT StorerKey) FROM ORDERS (NOLOCK), LOADPLANDETAIL(NOLOCK)
                 WHERE LOADPLANDETAIL.OrderKey = ORDERS.OrderKey AND   LOADPLANDETAIL.LoadKey = @c_LoadKey ) = 1
            BEGIN
               -- Only 1 storer found
               SET @cStorerKey = ''
               SELECT @cStorerKey = (SELECT DISTINCT StorerKey
                                     FROM   ORDERS(NOLOCK), LOADPLANDETAIL (NOLOCK)
                                     WHERE  LOADPLANDETAIL.OrderKey = ORDERS.OrderKey
                                     AND     LOADPLANDETAIL.LoadKey = @c_LoadKey )

               IF EXISTS (SELECT 1 FROM STORERCONFIG(NOLOCK) WHERE CONFIGKEY = 'AUTOSCANIN' AND
                          SValue = '1' AND StorerKey = @cStorerKey)
               BEGIN
                  -- Configkey is setup
                  IF NOT Exists(SELECT 1 FROM PickingInfo (NOLOCK) WHERE PickSlipNo = @c_PickHeaderKey)
                  BEGIN
                     INSERT INTO PickingInfo  (PickSlipNo, ScanInDate, PickerID, ScanOutDate)
                     VALUES (@c_PickHeaderKey, GetDate(), sUser_sName(), NULL)
                  END
               END -- Configkey is setup
            END -- Only 1 storer found
         END

      END  -- @c_FirstTime = 'Y'
   END -- IF @n_continue = 1 or @n_continue = 2

   IF (@n_continue = 1 or @n_continue = 2) AND ISNULL(@c_PreGenRptData,'') IN ('','0')
   BEGIN
     SELECT LoadPlanDetail.LoadKey,
         PICKHEADER.PickHeaderKey,
         LoadPlan.Route,
         LoadPlan.AddDate,
         PICKDETAIL.Loc,
         TRIM(PICKDETAIL.Sku),
         PICKDETAIL.Qty,
         TRIM(SKU.DESCR),
         PACK.CaseCnt,
         PACK.PackKey,
         LOTATTRIBUTE.Lottable04,
         LOC.Putawayzone,
         loc.LogicalLocation
     FROM LoadPlanDetail (NOLOCK)
     JOIN ORDERDETAIL (NOLOCK) ON ( LoadPlanDetail.LoadKey = ORDERDETAIL.LoadKey AND
                                    LoadPlanDetail.OrderKey = ORDERDETAIL.OrderKey)
     JOIN ORDERS (NOLOCK) ON ( ORDERDETAIL.OrderKey = ORDERS.OrderKey )
     JOIN PICKDETAIL (NOLOCK) ON ( ORDERDETAIL.OrderKey = PICKDETAIL.OrderKey ) AND
                    ( ORDERDETAIL.OrderLineNumber = PICKDETAIL.OrderLineNumber )
     JOIN SKU  (NOLOCK) ON  ( SKU.StorerKey = PICKDETAIL.Storerkey ) AND
                           ( SKU.Sku = PICKDETAIL.Sku )
     JOIN LoadPlan (NOLOCK) ON ( LoadPlanDetail.LoadKey = LoadPlan.LoadKey )
     JOIN PACK (NOLOCK) ON ( PACK.PackKey = SKU.PACKKey )
     JOIN PICKHEADER (NOLOCK) ON ( PICKHEADER.ExternOrderKey = LoadPlan.LoadKey ) AND
                           ( PICKHEADER.Zone = '7' )
     JOIN LOTATTRIBUTE (NOLOCK) ON ( LOTATTRIBUTE.Storerkey = PICKDETAIL.Storerkey
            AND LOTATTRIBUTE.SKU = PICKDETAIL.SKU
            AND LOTATTRIBUTE.Lot = PICKDETAIL.Lot)
     JOIN LOC (NOLOCK) ON PICKDETAIL.LOC = LOC.Loc
     WHERE ( LoadPlanDetail.LoadKey = @c_LoadKey )
     ORDER BY LOC.Putawayzone,CASE WHEN ISNULL(loc.LogicalLocation,'') = '' THEN 0 ELSE 1 END, Loc.LogicalLocation, PICKDETAIL.Loc,PICKDETAIL.Sku  --(JH01) add , Loc.LogicalLocation
   END

   EXIT_SP:

   IF @n_continue=3  -- Error Occured - Process And Return
   BEGIN
     SELECT @b_success = 0
     IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_StartTranCnt
     BEGIN
        ROLLBACK TRAN
     END
     ELSE
     BEGIN
       WHILE @@TRANCOUNT > @n_StartTranCnt
       BEGIN
          COMMIT TRAN
       END
     END
     EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_RPT_LP_PLISTC_001_2'
     RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
     RETURN
   END
   ELSE
   BEGIN
      /* Error Did Not Occur , Return Normally */
      SELECT @b_success = 1
      WHILE @@TRANCOUNT > @n_StartTranCnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END
   /* End Return Statement */
END -- Procedure

GO