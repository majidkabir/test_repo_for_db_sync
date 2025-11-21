SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_GetPickSlipWave22                              */
/* Creation Date: 2020-05-19                                            */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-13441 - Porsche Wave Pickslip                           */
/*                                                                      */
/* Usage: RCM -> Generate Pickslip (ReportType: PLIST_WAVE)             */
/*                                                                      */
/* Called By: r_dw_print_wave_pickslip_22                               */
/*                                                                      */
/* Revision: 1.0                                                        */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/************************************************************************/

CREATE PROC [dbo].[isp_GetPickSlipWave22] (@c_wavekey NVARCHAR(10))
 AS
 BEGIN

   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_continue           INT,
           @c_errmsg             NVARCHAR(255),
           @b_success            INT,
           @n_err                INT,
           @n_pickslips_required INT,
           @c_pickheaderkey      NVARCHAR(10),
           @c_firsttime          NVARCHAR(10),
           @c_PrintedFlag        NVARCHAR(10),
           @n_starttcnt          INT = @@TRANCOUNT

   -- Use Zone as a UOM Picked 1 - Pallet, 2 - Case, 6 - Each, 8 - By Order
   IF EXISTS(SELECT 1 FROM PickHeader WITH (NOLOCK) WHERE Wavekey = @c_wavekey AND Zone = '8')
   BEGIN
      SELECT @c_firsttime = 'N'
      SELECT @c_PrintedFlag = 'Y'
   END
   ELSE
   BEGIN
      SELECT @c_firsttime = 'Y'
      SELECT @c_PrintedFlag = 'N'
   END -- Record Not Exists

   WHILE @@TRANCOUNT > 0
      COMMIT TRAN

   -- Uses PickType as a Printed Flag
   IF @c_firsttime = 'N' 
   BEGIN
      BEGIN TRAN
   
      UPDATE PickHeader
      SET PickType = '1',
          TrafficCop = NULL,
          EditWho = SUSER_SNAME(),
          EditDate = GETDATE()
      WHERE WaveKey = @c_wavekey
      AND Zone = '8'
      AND PickType = '0'

      SELECT @n_err = @@ERROR

      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
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
            SELECT @n_continue = 3
            ROLLBACK TRAN
            GOTO QUIT_SP
         END
      END
   END

   CREATE TABLE #TEMP_PICK
         ( PickSlipNo      NVARCHAR(10) NULL,
         LoadKey           NVARCHAR(10),
         WaveKey           NVARCHAR(10),
         Storerkey         NVARCHAR(15),
         Consigneekey      NVARCHAR(15) NULL,
         C_Contact1        NVARCHAR(45) NULL,
         C_Addresses       NVARCHAR(255) NULL,
         C_Phone1          NVARCHAR(45) NULL,
         C_Address2        NVARCHAR(45) NULL,
         OrderKey          NVARCHAR(10),
         ExternOrderkey    NVARCHAR(50),
         UserDefine10      NVARCHAR(10) NULL,
         Loc               NVARCHAR(10) NULL,
         Sku               NVARCHAR(20) NULL,
         AltSku            NVARCHAR(20) NULL,
         Notes1            NVARCHAR(500) NULL,
         Notes2            NVARCHAR(500) NULL,
         IB_UOM            NVARCHAR(10) NULL,
         IB_RPT_UOM        NVARCHAR(10) NULL,
         Qty               INT,
         PrintedFlag       NVARCHAR(10) NULL )
   
   INSERT INTO #TEMP_PICK
   SELECT DISTINCT
         (SELECT PICKHEADER.PickHeaderKey FROM PICKHEADER (NOLOCK)
          WHERE PICKHEADER.Wavekey = @c_wavekey
          AND PICKHEADER.OrderKey = ORDERS.OrderKey
          AND PICKHEADER.ZONE = '8') AS Pickslipno,
          ORDERS.Loadkey,
          @c_wavekey AS Wavekey,
          ORDERS.Storerkey,
          ORDERS.Consigneekey,
          ORDERS.C_Contact1,
          LTRIM(RTRIM(ISNULL(ORDERS.C_State,''))) + ' ' + LTRIM(RTRIM(ISNULL(ORDERS.C_City,''))) + ' ' + 
          LTRIM(RTRIM(ISNULL(ORDERS.C_Address1,''))) AS C_Addresses,
          ISNULL(ORDERS.C_Phone1,'') AS C_Phone1,
          ISNULL(ORDERS.C_Address2,'') AS C_Address2,
          ORDERS.Orderkey,
          ORDERS.Externorderkey,
          ORDERS.Userdefine10,
          PICKDETAIL.LOC,
          ORDERDETAIL.SKU,
          SKU.Altsku,
          REVERSE(SUBSTRING(REVERSE(SKU.NOTES1),CHARINDEX('||',REVERSE(SKU.NOTES1)) ,500)) AS Notes1,
          --(SUBSTRING(REVERSE(SKU.NOTES1),CHARINDEX('||',REVERSE(SKU.NOTES1)) ,500)) AS Notes1,
          REVERSE(SUBSTRING(REVERSE(sku.NOTES2),CHARINDEX('||',REVERSE(sku.NOTES2)) +2,500)) AS Notes2,
          SKU.IB_UOM,
          SKU.IB_RPT_UOM,
          SUM(PICKDETAIL.Qty) AS Qty,
          @c_PrintedFlag
   FROM ORDERS (NOLOCK)
   JOIN ORDERDETAIL (NOLOCK) ON ORDERDETAIL.Orderkey = ORDERS.Orderkey
   JOIN PICKDETAIL (NOLOCK) ON ORDERDETAIL.Orderkey = PICKDETAIL.Orderkey AND ORDERDETAIL.SKU = PICKDETAIL.SKU
                           AND ORDERDETAIL.OrderLineNumber = PICKDETAIL.OrderLineNumber
   JOIN SKU (NOLOCK) ON SKU.SKU = PICKDETAIL.SKU AND SKU.Storerkey = ORDERS.Storerkey
   JOIN WAVEDETAIL (NOLOCK) ON WAVEDETAIL.Orderkey = ORDERS.Orderkey
   WHERE WAVEDETAIL.Wavekey = @c_wavekey
   GROUP BY ORDERS.Loadkey,
            ORDERS.Storerkey,
            ORDERS.Consigneekey,
            ORDERS.C_Contact1,
            LTRIM(RTRIM(ISNULL(ORDERS.C_State,''))) + ' ' + LTRIM(RTRIM(ISNULL(ORDERS.C_City,''))) + ' ' + 
            LTRIM(RTRIM(ISNULL(ORDERS.C_Address1,''))),
            ISNULL(ORDERS.C_Phone1,''),
            ISNULL(ORDERS.C_Address2,''),
            ORDERS.Orderkey,
            ORDERS.Externorderkey,
            ORDERS.Userdefine10,
            PICKDETAIL.LOC,
            ORDERDETAIL.SKU,
            SKU.Altsku,
            REVERSE(SUBSTRING(REVERSE(SKU.NOTES1),CHARINDEX('||',REVERSE(SKU.NOTES1)) ,500)),
            --(SUBSTRING(REVERSE(SKU.NOTES1),CHARINDEX('||',REVERSE(SKU.NOTES1)) ,500)),
            REVERSE(SUBSTRING(REVERSE(sku.NOTES2),CHARINDEX('||',REVERSE(sku.NOTES2)) +2,500)),
            SKU.IB_UOM,
            SKU.IB_RPT_UOM

   SELECT @n_pickslips_required = COUNT(DISTINCT OrderKey)
   FROM #TEMP_PICK
   WHERE PickSlipNo IS NULL

   IF @n_pickslips_required > 0
   BEGIN
      EXECUTE nspg_GetKey 'PICKSLIP', 9, @c_pickheaderkey OUTPUT, @b_success OUTPUT, @n_err  OUTPUT, @c_errmsg OUTPUT, 0, @n_pickslips_required

      IF @n_err <> 0
      BEGIN
         SET @n_continue = 3
         GOTO QUIT_SP
      END

      BEGIN TRAN

      INSERT INTO PICKHEADER (PickHeaderKey, OrderKey, WaveKey, PickType, Zone, TrafficCop, StorerKey)
      SELECT 'P' + RIGHT ( REPLICATE ('0', 9) +
      dbo.fnc_LTrim( dbo.fnc_RTrim(
      STR(CAST(@c_pickheaderkey AS INT) + (SELECT COUNT(DISTINCT orderkey)
                                           FROM #TEMP_PICK AS Rank
                                           WHERE Rank.OrderKey < #TEMP_PICK.OrderKey )
          ) -- str
          )) -- dbo.fnc_RTrim
          , 9)
         , OrderKey, WaveKey, '0', '8', '', StorerKey
      FROM #TEMP_PICK WHERE PickSlipNo IS NULL
      GROUP By WaveKey, OrderKey, StorerKey

      SELECT @n_err = @@ERROR

      IF @n_err <> 0
      BEGIN
         ROLLBACK TRAN
         GOTO QUIT_SP
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > 0 
            COMMIT TRAN
      END

      UPDATE #TEMP_PICK
      SET PickSlipNo = PICKHEADER.PickHeaderKey
      FROM PICKHEADER (NOLOCK)
      WHERE PICKHEADER.WaveKey = #TEMP_PICK.Wavekey
      AND   PICKHEADER.OrderKey = #TEMP_PICK.OrderKey
      AND   PICKHEADER.Zone = '8'
      AND   #TEMP_PICK.PickSlipNo IS NULL
   END

   SELECT * FROM #TEMP_PICK 
   ORDER BY Orderkey, Loc, SKU

QUIT_SP:
   IF OBJECT_ID('tempdb..#TEMP_PICK') IS NOT NULL
      DROP TABLE #TEMP_PICK

   IF @n_continue=3  -- Error Occured - Process And Return    
   BEGIN    
      SELECT @b_success = 0    
      IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_starttcnt    
      BEGIN    
         ROLLBACK TRAN    
      END    
      ELSE    
      BEGIN    
         WHILE @@TRANCOUNT > @n_starttcnt    
         BEGIN    
            COMMIT TRAN    
         END    
      END    
      execute nsp_logerror @n_err, @c_errmsg, "isp_GetPickSlipWave22"    
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

END

GO