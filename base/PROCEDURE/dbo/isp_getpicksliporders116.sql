SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_GetPickSlipOrders116                                */
/* Creation Date: 14-Jan-2021                                           */
/* Copyright: LF Logistics                                              */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-16037 - [PH] - Adidas Ecom - Normal Pickslip            */
/*        :                                                             */
/* Called By:r_dw_print_pickorder116                                    */
/*          :                                                           */
/* GitLab Version: 1.0                                                  */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver Purposes                                  */
/* 16-June-2021 Mingle    1.1 Add ShowWaveKey(ML01)                     */
/************************************************************************/
CREATE PROC [dbo].[isp_GetPickSlipOrders116]
            @c_Loadkey   NVARCHAR(10)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt       INT
         , @n_Continue        INT 
         , @b_Success         INT
         , @n_Err             INT
         , @c_Errmsg          NVARCHAR(255)

         , @n_NoOfReqPSlip    INT
         , @c_Orderkey        NVARCHAR(10)
         , @c_PickSlipNo      NVARCHAR(10)
         , @c_PickHeaderKey   NVARCHAR(10)

         , @c_ConsoOrderkey   NVARCHAR(10)
         , @c_LocCategory     NVARCHAR(10)

         , @c_PrintedFlag     CHAR(1)

         , @c_PickDetailKey   NVARCHAR(10)
          ,@c_Wavekey         NVARCHAR(10)
         , @c_OrderLineNumber NVARCHAR(5)

         , @n_PageNo          INT
         , @n_PageGroup       INT
         , @n_RowPerPage      FLOAT

   SET @n_StartTCnt= @@TRANCOUNT
   SET @n_Continue = 1
   SET @b_Success  = 1
   SET @n_Err      = 0
   SET @c_Errmsg   = ''

   WHILE @@TRANCOUNT > 0 
   BEGIN
      COMMIT TRAN
   END 
   
   CREATE TABLE #TMP_PD116
      ( RowNo              INT IDENTITY(1,1)  NOT NULL PRIMARY KEY  
      , PickSlipNo         NVARCHAR(10)  NULL
      , [Type]             NVARCHAR(10)  NULL
      , StorerKey          NVARCHAR(15)  NULL
      , Loadkey            NVARCHAR(15)  NULL
      , Salesman           NVARCHAR(50)  NULL
      , LocationCategory   NVARCHAR(10)  NULL
      , Facility           NVARCHAR(5)   NULL
      , OrderKey           NVARCHAR(10)  NULL
      , Loc                NVARCHAR(20)  NULL
      , SKU                NVARCHAR(20)  NULL
      , DESCR              NVARCHAR(255) NULL
      , Qty                INT           NULL
      , UOM                NVARCHAR(10)  NULL
      , PrintedFlag        NVARCHAR(10)  NULL
      , Wavekey            NVARCHAR(10)  NULL      
      , ExternOrderKey     NVARCHAR(50)  NULL  
      , ShowWaveKey        NVARCHAR(5)   NULL      --ML01  
   )

   INSERT INTO #TMP_PD116 ( [Type], PickSlipNo, StorerKey, Loadkey, Salesman, 
                            LocationCategory, Facility, OrderKey, Loc, SKU, DESCR, Qty, UOM, PrintedFlag, Wavekey, ExternOrderKey,ShowWaveKey) --ML01
   SELECT OH.[Type]
         ,PH.PickHeaderKey
         ,OH.StorerKey
         ,OH.Loadkey
         ,OH.Salesman
         ,L.LocationCategory
         ,OH.Facility
         ,OH.OrderKey
         ,PD.Loc
         ,PD.SKU
         ,S.DESCR
         ,SUM(PD.Qty)
         ,OD.UOM
         ,'N'
         ,OH.UserDefine09
         ,OH.ExternOrderKey
         ,ISNULL(CL.SHORT,'') AS ShowWaveKey      --ML01 
   FROM ORDERS OH (NOLOCK)
   JOIN ORDERDETAIL OD (NOLOCK) ON OH.OrderKey = OD.OrderKey
   JOIN PICKDETAIL PD (NOLOCK) ON PD.OrderKey = OH.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber
                              AND PD.SKU = OD.SKU
   JOIN LOC L (NOLOCK) ON PD.LOC = L.LOC
   JOIN SKU S (NOLOCK) ON S.SKU = PD.SKU AND S.StorerKey = PD.Storerkey
   JOIN LOADPLANDETAIL LPD (NOLOCK) ON LPD.OrderKey = OH.OrderKey
   LEFT JOIN PICKHEADER PH (NOLOCK) ON PH.OrderKey = OH.OrderKey AND PH.ConsoOrderKey = L.LocationCategory
   LEFT JOIN CODELKUP CL WITH (NOLOCK) ON (CL.LISTNAME = 'REPORTCFG' AND CL.CODE = 'ShowWaveKey'      --M01
                                             AND CL.LONG = 'r_dw_print_pickorder116' AND CL.STORERKEY = PD.STORERKEY )
   WHERE LPD.LoadKey = @c_Loadkey
   GROUP BY OH.[Type]
           ,PH.PickHeaderKey
           ,OH.StorerKey
           ,OH.Loadkey
           ,OH.Salesman
           ,L.LocationCategory
           ,OH.Facility
           ,OH.OrderKey
           ,PD.Loc
           ,PD.SKU
           ,S.DESCR
           ,OD.UOM
           ,OH.UserDefine09
           ,OH.ExternOrderKey
           ,ISNULL(CL.SHORT,'')      --ML01 

   IF NOT EXISTS (SELECT 1
                  FROM #TMP_PD116
               )
   BEGIN
      GOTO QUIT_SP
   END
   
   SET @n_NoOfReqPSlip  = 0

   SELECT @n_NoOfReqPSlip = COUNT(DISTINCT TPK.Orderkey + TPK.LocationCategory + TPK.Loadkey + TPK.Wavekey)
   FROM #TMP_PD116 TPK
   WHERE NOT EXISTS ( SELECT 1
                      FROM PICKHEADER PH WITH (NOLOCK) 
                      WHERE PH.OrderKey =  TPK.Orderkey 
                      AND PH.ConsoOrderkey = TPK.LocationCategory
                      AND PH.ExternOrderkey = TPK.Loadkey
                      AND PH.WaveKey = TPK.Wavekey
                    )

   IF @n_NoOfReqPSlip > 0 
   BEGIN
      EXECUTE nspg_GetKey 
              'PICKSLIP'
            , 9
            , @c_PickSlipNo   OUTPUT
            , @b_Success      OUTPUT
            , @n_Err          OUTPUT
            , @c_Errmsg       OUTPUT
            , 0
            , @n_NoOfReqPSlip

      IF @b_success <> 1 
      BEGIN
         SET @n_Continue = 3
         GOTO QUIT_SP
      END
   END

   DECLARE CUR_PSLIP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT
          TPK.Loadkey
         ,TPK.Orderkey
         ,TPK.LocationCategory
         ,PickHeaderkey = ISNULL(RTRIM(PH.PickHeaderKey),'')
         ,TPK.Wavekey
   FROM #TMP_PD116 TPK
   LEFT JOIN PICKHEADER PH WITH (NOLOCK) ON (TPK.Orderkey = PH.Orderkey)
                                        AND (TPK.LocationCategory = PH.ConsoOrderKey)
                                        AND (TPK.Loadkey = PH.ExternOrderkey)
                                        AND (TPK.Wavekey = PH.WaveKey)
   ORDER BY TPK.Loadkey
           ,TPK.Orderkey
           ,TPK.LocationCategory
           ,ISNULL(RTRIM(PH.PickHeaderKey),'')
           ,TPK.Wavekey

   OPEN CUR_PSLIP
   
   FETCH NEXT FROM CUR_PSLIP INTO @c_Loadkey
                                 ,@c_Orderkey
                                 ,@c_LocCategory
                                 ,@c_PickHeaderKey
                                 ,@c_Wavekey

   WHILE @@FETCH_STATUS <> -1
   BEGIN
      BEGIN TRAN
      IF @c_PickHeaderKey = ''
      BEGIN
         SET @c_PickHeaderKey = 'P' + @c_PickSlipNo

         INSERT INTO PICKHEADER (PickHeaderKey, Orderkey, ExternOrderKey, ConsoOrderkey, PickType, Zone, TrafficCop, LoadKey, WaveKey)
         VALUES (@c_PickHeaderKey, @c_Orderkey, @c_Loadkey, @c_LocCategory, '0', '3', NULL, @c_Loadkey, @c_Wavekey)

         SET @n_err = @@ERROR
         IF @n_err <> 0
         BEGIN
            SET @n_Continue = 3
            GOTO QUIT_SP
         END

         SET @c_PickSlipNo = RIGHT('000000000' + CONVERT(NVARCHAR(9), CONVERT(INT, @c_PickSlipNo) + 1),9)

         SET @c_PrintedFlag = 'N'
      END
      ELSE
      BEGIN
         UPDATE PICKHEADER WITH (ROWLOCK)
         SET PickType = '1'
            ,EditWho = SUSER_NAME()
            ,EditDate= GETDATE()
            ,TrafficCop = NULL
         FROM PICKHEADER
         WHERE PickHeaderKey = @c_PickHeaderKey

         SET @n_err = @@ERROR
         IF @n_err <> 0
         BEGIN
            SET @n_Continue = 3
            GOTO QUIT_SP
         END

         SET @c_PrintedFlag = 'Y'
      END

      UPDATE #TMP_PD116
      SET PickSlipNo  = @c_PickHeaderKey
         ,PrintedFlag = @c_PrintedFlag
      WHERE Loadkey   = @c_Loadkey
      AND Orderkey = @c_Orderkey
      AND LocationCategory  = @c_LocCategory
      AND Wavekey = @c_Wavekey

      WHILE @@TRANCOUNT > 0 
      BEGIN
         COMMIT TRAN
      END
          
      FETCH NEXT FROM CUR_PSLIP INTO @c_Loadkey
                                    ,@c_Orderkey
                                    ,@c_LocCategory
                                    ,@c_PickHeaderKey
                                    ,@c_Wavekey

   END
   CLOSE CUR_PSLIP
   DEALLOCATE CUR_PSLIP
   
   SELECT TP.RowNo 
         ,TP.PickSlipNo 
         ,TP.Loadkey  
         ,TP.Facility    
         ,TP.StorerKey  
         ,TP.Salesman 
         ,TP.[Type]            
         ,TP.LocationCategory 
         ,TP.OrderKey        
         ,TP.Loc             
         ,TP.SKU             
         ,TP.DESCR           
         ,TP.Qty             
         ,TP.UOM             
         ,TP.PrintedFlag  
         ,TP.ExternOrderKey
         ,TP.Wavekey   
         ,TP.ShowWaveKey      --ML01 
   FROM #TMP_PD116 AS TP
   ORDER BY TP.RowNo

QUIT_SP:
   IF OBJECT_ID('tempdb..#TMP_PD116') IS NOT NULL
      DROP TABLE #TMP_PD116

   IF CURSOR_STATUS( 'LOCAL', 'CUR_PSLIP') in (0 , 1)  
   BEGIN
      CLOSE CUR_PSLIP
      DEALLOCATE CUR_PSLIP
   END

   IF @n_Continue = 3
   BEGIN
      IF @@TRANCOUNT > 0
      BEGIN
         ROLLBACK TRAN
      END 
   END
   ELSE
   BEGIN
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END

   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END
   
END -- procedure

GO