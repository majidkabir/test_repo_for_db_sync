SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: isp_RefreshCtnTotal                                   */
/* Creation Date: 10-OCT-2013                                              */
/* Copyright: IDS                                                          */
/* Written by: YTWan                                                       */
/*                                                                         */
/* Purpose: SOS#291410                                                     */
/*        :                                                                */
/*                                                                         */
/* Called By: Calculate Totalcartons, Weight, Cube for orderekey when      */
/*            Print VicsBol at MBOL Screen                                 */
/*                                                                         */
/* PVCS Version: 1.0                                                       */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author  Ver   Purposes                                     */
/* 01-NOV-2013  YTWan   1.1   Fixed for issue updating NULL value. (Wan01) */
/***************************************************************************/
CREATE PROC [dbo].[isp_RefreshCtnTotal]
            @c_MBOLKey          NVARCHAR(10)
         ,  @b_Success          INT             OUTPUT
         ,  @n_Err              INT             OUTPUT
         ,  @c_ErrMsg           NVARCHAR(255)   OUTPUT
AS
BEGIN
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_Continue              INT
         , @n_StartTCnt             INT

         , @n_TotalCartons          INT
         , @n_TotalWeight           FLOAT         
         , @n_TotalCube             FLOAT        
         
         , @n_Weight                FLOAT          
         , @n_Cube                  FLOAT         

         , @n_CartonNo              INT
         , @c_PickSlipNo            NVARCHAR(10)

         , @c_ConsoOrderkey         NVARCHAR(30)
         , @c_Storerkey             NVARCHAR(15)
         , @c_Orderkey              NVARCHAR(10)
         , @c_Loadkey               NVARCHAR(10)
         , @c_CartonType            NVARCHAR(10)
         
         , @c_Facility              NVARCHAR(10)      --Larry
         , @c_SkipMBOLRecal         NVARCHAR(10)      --Larry
   
   SET @n_Continue = 1
   SET @n_StartTCnt= @@TRANCOUNT

   WHILE @@TRANCOUNT > 0 
   BEGIN
      COMMIT TRAN
   END

   BEGIN TRAN

   --Larry (START)
   SELECT TOP 1  @c_Storerkey = Storerkey
            , @c_Facility = Facility
   FROM ORDERS O WITH (NOLOCK)
   WHERE MBOLKey = @c_MBOLkey
   
   EXECUTE nspGetRight
            @c_Facility,      -- facility
            @c_Storerkey,     -- Storerkey
            NULL,             -- Sku
            'SKIPMBOLRECAL',   -- Configkey
            @b_Success        OUTPUT,
            @c_SkipMBOLRecal  OUTPUT,
            @n_err            OUTPUT,
            @c_ErrMsg         OUTPUT

   IF ISNULL(RTRIM(@c_SkipMBOLRecal),'') = '1'
   BEGIN
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END
   --Larry (END)
    
   DECLARE CUR_ORD CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
   SELECT O.Orderkey
         ,O.Storerkey
         ,O.Loadkey
   FROM ORDERS O  WITH (NOLOCK)
   JOIN MBOLDETAIL MD WITH (NOLOCK) ON (O.Orderkey = MD.Orderkey)
   WHERE MD.MBOLKey = @c_MBOLkey
   OPEN CUR_ORD

   FETCH NEXT FROM CUR_ORD INTO @c_Orderkey, @c_Storerkey, @c_Loadkey
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      SET @n_TotalCartons= 0
      SET @n_TotalWeight = 0
      SET @n_TotalCube   = 0
      SET @n_Weight      = 0
      SET @n_Cube        = 0

      SELECT  TOP 1 @c_ConsoOrderkey = ISNULL(RTRIM(ConsoOrderkey),'') 
      FROM ORDERDETAIL WITH (NOLOCK)
      WHERE Orderkey = @c_Orderkey

      IF @c_ConsoOrderkey = '' -- DISCRETE PICKSLIP
      BEGIN
         SELECT @c_PickSlipNo = PickSlipNo
         FROM PACKHEADER WITH (NOLOCK) 
         WHERE Orderkey = @c_Orderkey

         SELECT @n_TotalCartons = COUNT(DISTINCT PD.LabelNo)
               ,@n_TotalWeight  = SUM (CASE WHEN ISNULL(PI.Weight,0) > 0 THEN PI.Weight ELSE (PD.Qty * ISNULL(SKU.StdGrossWgt,0)) END)
               ,@n_TotalCube    = SUM (CASE WHEN ISNULL(PI.Cube,0)   > 0 THEN PI.Cube   ELSE (PD.Qty * ISNULL(SKU.StdCube,0)) END)
         FROM PACKHEADER PH    WITH (NOLOCK) 
         JOIN PACKDETAIL PD    WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)
         JOIN SKU        SKU   WITH (NOLOCK) ON (PD.StorerKey = SKU.StorerKey)  AND (PD.SKU = SKU.SKU) 
         LEFT JOIN PACKINFO PI WITH (NOLOCK) ON (PD.PickSlipNo = PI.PickSlipNo) AND (PD.CartonNo = PI.CartonNo)
         WHERE PH.PickSlipNo = @c_PickSlipNo

         GOTO ORDERINFO_UPD
      END

      --ORDER WITH Multiple ConsoOrderkey
      IF EXISTS (SELECT 1
                 FROM ORDERDETAIL WITH (NOLOCK)
                 WHERE Orderkey = @c_Orderkey
                 GROUP BY Orderkey
                 HAVING COUNT(DISTINCT ConsoOrderkey) > 1)
      BEGIN
--         SELECT @n_TotalCartons = COUNT(DISTINCT PD.LabelNo)
--         FROM PACKHEADER PH WITH (NOLOCK) 
--         JOIN PACKDETAIL PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)
--         WHERE PH.ConsoOrderkey = @c_ConsoOrderkey
         
         SELECT @n_TotalCartons = COUNT(DISTINCT CASE WHEN PD.CaseID = '' THEN NULL ELSE PD.CaseID END)
               ,@n_TotalWeight = SUM(PD.QTY * ISNULL(SKU.StdGrossWgt,0))
               ,@n_TotalCube   = SUM(PD.QTY * ISNULL(SKU.StdCube,0))
         FROM PICKDETAIL  PD WITH (NOLOCK) 
         JOIN SKU         SKU WITH (NOLOCK) ON (PD.Storerkey = SKU.Storerkey) AND (PD.Sku = SKU.Sku) 
         WHERE Orderkey = @c_Orderkey 

         GOTO ORDERINFO_UPD
      END
                 
      --ORDER WITH 1 ConsoOrderkey
      DECLARE CUR_PACKINFO CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
      --SELECT DISTINCT PD.PickslipNo, PD.CartonNo, PI.CartonType, PI.Weight, PI.Cube                                     --(wan01)
      SELECT DISTINCT PD.PickslipNo, PD.CartonNo, ISNULL(RTRIM(PI.CartonType),''), ISNULL(PI.Weight,0), ISNULL(PI.Cube,0) --(Wan01)
      FROM ORDERDETAIL OD   WITH (NOLOCK)
      JOIN PICKDETAIL  PCK  WITH (NOLOCK) ON (OD.OrderKey = PCK.Orderkey) AND (OD.OrderlineNumber = PCK.OrderlineNumber)
      JOIN PACKDETAIL  PD   WITH (NOLOCK) ON (PCK.PickSlipNo = PD.PickSlipNo) AND (PCK.DropID = PD.DropID)
      LEFT JOIN PACKINFO PI WITH (NOLOCK) ON (PD.PickSlipNo  = PI.PickSlipNo) AND (PD.CartonNo = PI.CartonNo)
      WHERE OD.Orderkey = @c_Orderkey
      ORDER BY PD.PickslipNo, PD.CartonNo

      OPEN CUR_PACKINFO
      FETCH NEXT FROM CUR_PACKINFO INTO @c_PickSlipNo, @n_CartonNo, @c_CartonType, @n_Weight, @n_Cube 
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         IF @n_Cube = 0
         BEGIN
            SELECT @n_Cube = ISNULL(C.Cube,0)
            FROM STORER        S WITH (NOLOCK)
            JOIN CARTONIZATION C WITH (NOLOCK) ON (S.CartonGroup = C.CartonizationGroup) 
             WHERE S.Storerkey = @c_Storerkey
            AND    C.CartonType= @c_CartonType
         END

         IF @n_Weight = 0 OR @n_Cube = 0
         BEGIN
            SELECT @n_Weight = CASE WHEN @n_Weight > 0 THEN @n_Weight ELSE ISNULL( SUM( PD.QTY * ISNULL(SKU.StdGrossWgt,0)), 0) END
               ,   @n_Cube   = CASE WHEN @n_Cube > 0   THEN @n_Cube ELSE ISNULL( SUM( PD.QTY * ISNULL(SKU.StdCube,0)), 0) END
            FROM PackDetail PD (NOLOCK)   
            INNER JOIN SKU WITH (NOLOCK) ON (SKU.StorerKey = PD.StorerKey AND SKU.SKU = PD.SKU) 
            WHERE PICKSLIPNO = @c_PickslipNo
            AND   CartonNo   = @n_CartonNo
         END
         SET @n_TotalCartons = @n_TotalCartons + 1
         SET @n_TotalWeight = @n_TotalWeight + @n_Weight
         SET @n_TotalCube   = @n_TotalCube + @n_Cube

         FETCH NEXT FROM CUR_PACKINFO INTO @c_PickSlipNo, @n_CartonNo, @c_CartonType, @n_Weight, @n_Cube 
      END
      CLOSE CUR_PACKINFO
      DEALLOCATE CUR_PACKINFO

--      SELECT @n_MBOLWeight '@n_MBOLWeight', @n_TotalWeight '@n_TotalWeight'

      ORDERINFO_UPD:
      --SELECT 'UPDATE MBOLDETAIL', @c_Mbolkey '@c_MBOLKey', @c_Orderkey '@c_Orderkey'
      --SELECT 'UPDATE LOADPLABDETAIL', @c_Mbolkey '@c_MBOLKey', @c_Orderkey '@c_Orderkey'

      UPDATE LOADPLANDETAIL WITH (ROWLOCK)
      SET CaseCnt= @n_TotalCartons
         ,Weight = @n_TotalWeight
         ,Cube   = @n_TotalCube
         ,EditDate = GETDATE()
         ,EditWho  = SUSER_Name()
         ,Trafficcop = NULL
      WHERE Loadkey = @c_Loadkey
      AND   Orderkey= @c_Orderkey

      IF @@ERROR <> 0  
      BEGIN  
         SET @n_Continue = 3
         SET @n_Err = 14001
         SELECT @c_ErrMsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Error Update LoadPlanDetail Table.'
         GOTO QUIT
      END 

      UPDATE MBOLDETAIL WITH (ROWLOCK)
      SET TotalCartons = @n_TotalCartons
         ,Weight = @n_TotalWeight
         ,Cube   = @n_TotalCube
         ,EditDate = GETDATE()
         ,EditWho  = SUSER_Name()
         ,Trafficcop = NULL
      WHERE MBOLKey = @c_MBOLkey
      AND   Orderkey= @c_Orderkey 

      IF @@ERROR <> 0  
      BEGIN  
         SET @n_Continue = 3
         SELECT @n_Err = 14002
         SELECT @c_ErrMsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Error Update MBOLDetail Table.'

         GOTO QUIT
      END
      FETCH NEXT FROM CUR_ORD INTO @c_Orderkey, @c_Storerkey, @c_Loadkey
   END 
   CLOSE CUR_ORD
   DEALLOCATE CUR_ORD

   QUIT:

   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END

   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SELECT @b_success = 0
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT >= @n_StartTCnt
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_StartTCnt
         BEGIN
            COMMIT TRAN
         END
      END

      execute nsp_logerror @n_err, @c_errmsg, 'isp_RefreshCtnTotal'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012

      RETURN
   END
   ELSE
   BEGIN
      SELECT @b_success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END
END

GO