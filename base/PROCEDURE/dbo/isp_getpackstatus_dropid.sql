SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Proc: isp_GetPackStatus_DropID                                */
/* Creation Date: 05-APR-2017                                           */
/* Copyright: LF Logistics                                              */
/* Written by: WAN                                                      */
/*                                                                      */
/* Purpose: WMS-1466 - CN & SG Logitech - Packing                       */
/*        :                                                             */
/* Called By:                                                           */
/*          :                                                           */
/* PVCS Version: 1.5                                                    */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 16-JUN-2017 Wan01    1.1   WMS-1466 - Use refno2 to get qtypacked    */
/* 30-Aug-2017 TLTING   1.2   Performance tune                          */
/* 20-Oct-2020 TLTING01 1.3   Performance tune - DropID check           */
/* 18-Nov-2020 LZG      1.4   INC1332162-Quit SP if blank DropID (ZG01) */  
/* 2022-03-24  Wan02    1.5   DevOps Combine Script                     */
/* 2022-03-24  Wan02    1.5   WMS-19299 - CN Logitech ToteID Packing CR */
/************************************************************************/
CREATE PROC [dbo].[isp_GetPackStatus_DropID] 
       @c_DropID  NVARCHAR(20)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt       INT
         , @n_Continue        INT
         
         , @c_Wavekey         NVARCHAR(10)

         --(Wan01) - START
         , @b_Success         INT               
         , @n_err             INT
         , @c_ErrMsg          NVARCHAR(255) 
         , @c_StorerKey                NVARCHAR(15)
         , @c_PACKToteSumQtyByRefNo2   NVARCHAR(30)
         --(Wan01) - END
         
         , @c_UserName        NVARCHAR(128)  = SUSER_SNAME()               --(Wan02)


   SET @n_StartTCnt = @@TRANCOUNT

   WHILE @@TRANCOUNT > 0 
   BEGIN
      COMMIT TRAN
   END;
   
   -- ZG01 (Start)  
   IF ISNULL(@c_DropID, '') = ''
   BEGIN
      DECLARE @t_Dummy TABLE
            (  Storerkey      NVARCHAR(15) NULL     
            ,  Sku            NVARCHAR(20) NULL     
            ,  QtyAllocated   INT   NULL            
            ,  QtyPacked      INT   NULL            
            ,  BalQty         INT   NULL            
            ,  rowfocusindicatorcol NVARCHAR(15) NULL
            ,  UserQtyPacked  INT   NULL  DEFAULT(0)        --Wan02
            )   
      SELECT Storerkey      
            ,  Sku            
            ,  QtyAllocated   
            ,  QtyPacked      
            ,  BalQty
            ,  rowfocusindicatorcol
            ,  UserQtyPacked                                --Wan02
      FROM @t_Dummy 
      GOTO QUIT_SP 
   END
   -- ZG01 (End)  


   SET @c_Wavekey = ''
   IF @c_DropID <> ''
   BEGIN
      SELECT TOP 1 @c_Wavekey  = Wavekey
               ,  @c_StorerKey = Storerkey            --(Wan01)
      FROM dbo.fnc_GetWaveOrder_DropID(@c_DropID);
      
      --(Wan01) - START
      SET @c_PACKToteSumQtyByRefNo2 = ''
      EXEC nspGetRight      
         @c_Facility  = NULL      
      ,  @c_StorerKey = @c_StorerKey      
      ,  @c_sku       = NULL      
      ,  @c_ConfigKey = 'PACKToteSumQtyByRefNo2'      
      ,  @b_Success   = @b_Success                 OUTPUT      
      ,  @c_authority = @c_PACKToteSumQtyByRefNo2  OUTPUT      
      ,  @n_err       = @n_err                     OUTPUT      
      ,  @c_errmsg    = @c_errmsg                  OUTPUT  
      --(Wan01) - END                
   END;


   IF @c_PACKToteSumQtyByRefNo2 =  '1'
   BEGIN

      WITH 
      PICK_ORD( Storerkey, Sku, QtyAllocated)
      AS (  SELECT PD.Storerkey
                  ,PD.Sku
                  ,QtyAllocated = ISNULL(SUM(PD.Qty),0)
            FROM PICKDETAIL PD WITH (NOLOCK)
            JOIN WAVEDETAIL WD WITH (NOLOCK) ON (PD.Orderkey = WD.Orderkey)
            WHERE PD.DropID = @c_DropID
            AND   WD.Wavekey= @c_Wavekey
            --AND @c_DropID <> ''                                                   --TLTING01
            GROUP BY PD.Storerkey
                  ,  PD.Sku
         )
      ,
         PACK_ORD( Storerkey, Sku, QtyPacked, UserQtyPacked)                        --(Wan02)
         AS (  SELECT PD.Storerkey
                     ,PD.Sku
                     ,QtyPacked = ISNULL(SUM(PD.Qty),0)
                     ,UserQtyPacked = SUM(IIF(PD.AddWho = @c_UserName, PD.Qty, 0))  --(Wan02)
               FROM PACKDETAIL PD WITH (NOLOCK) 
               JOIN PACKHEADER PH WITH (NOLOCK) ON (PD.PickSlipNo = PH.PickSlipNo)
               JOIN WAVEDETAIL WD WITH (NOLOCK) ON (PH.Orderkey = WD.Orderkey)
               WHERE  ( PD.RefNo2 = @c_DropID   )  -- AND @c_PACKToteSumQtyByRefNo2 =  '1'
               AND   WD.Wavekey= @c_Wavekey
               --AND   @c_DropID <> ''                                              --TLTING01
               GROUP BY PD.Storerkey
                     ,  PD.Sku          
            )

      SELECT PICK_ORD.Storerkey
            ,PICK_ORD.Sku
            ,QtyAllocated = PICK_ORD.QtyAllocated
            ,QtyPacked    = ISNULL(PACK_ORD.QtyPacked,0)
            ,BalQty       = PICK_ORD.QtyAllocated - ISNULL(PACK_ORD.QtyPacked,0)
          ,'    ' rowfocusindicatorcol 
            ,UserQtyPacked = ISNULL(PACK_ORD.UserQtyPacked,0)                       --(Wan02)               
      FROM PICK_ORD
      LEFT JOIN PACK_ORD ON  (PICK_ORD.Storerkey = PACK_ORD.Storerkey)
                         AND (PICK_ORD.Sku = PACK_ORD.Sku)
      ORDER BY PICK_ORD.Sku
      

   END
   ELSE
   BEGIN

      WITH 
      PICK_ORD( Storerkey, Sku, QtyAllocated)
      AS (  SELECT PD.Storerkey
                  ,PD.Sku
                  ,QtyAllocated = ISNULL(SUM(PD.Qty),0)
            FROM PICKDETAIL PD WITH (NOLOCK)
            JOIN WAVEDETAIL WD WITH (NOLOCK) ON (PD.Orderkey = WD.Orderkey)
            WHERE PD.DropID = @c_DropID
            AND   WD.Wavekey= @c_Wavekey
            --AND @c_DropID <> ''                                                   --TLTING01
            GROUP BY PD.Storerkey
                  ,  PD.Sku
         )
      ,
         PACK_ORD( Storerkey, Sku, QtyPacked, UserQtyPacked)                        --(Wan02)
         AS (  SELECT PD.Storerkey
                     ,PD.Sku
                     ,QtyPacked = ISNULL(SUM(PD.Qty),0)
                     ,UserQtyPacked = SUM(IIF(PD.AddWho = @c_UserName, PD.Qty, 0))  --(Wan02)
               FROM PACKDETAIL PD WITH (NOLOCK) 
               JOIN PACKHEADER PH WITH (NOLOCK) ON (PD.PickSlipNo = PH.PickSlipNo)
               JOIN WAVEDETAIL WD WITH (NOLOCK) ON (PH.Orderkey = WD.Orderkey)
               WHERE ( PD.DropID = @c_DropID  )    -- AND @c_PACKToteSumQtyByRefNo2 <> '1'
               AND   WD.Wavekey= @c_Wavekey
               --AND   @c_DropID <> ''                                              --TLTING01
               GROUP BY PD.Storerkey
                     ,  PD.Sku          
            )

      SELECT PICK_ORD.Storerkey
            ,PICK_ORD.Sku
            ,QtyAllocated = PICK_ORD.QtyAllocated
            ,QtyPacked    = ISNULL(PACK_ORD.QtyPacked,0)
            ,BalQty       = PICK_ORD.QtyAllocated - ISNULL(PACK_ORD.QtyPacked,0)
            ,'    ' rowfocusindicatorcol 
            ,UserQtyPacked = ISNULL(PACK_ORD.UserQtyPacked,0)                       --(Wan02)               
      FROM PICK_ORD
      LEFT JOIN PACK_ORD ON  (PICK_ORD.Storerkey = PACK_ORD.Storerkey)
                         AND (PICK_ORD.Sku = PACK_ORD.Sku)
      ORDER BY PICK_ORD.Sku

   END

    

QUIT_SP:

   WHILE @@TRANCOUNT < @n_StartTCnt 
   BEGIN
      BEGIN TRAN
   END

END -- procedure

GO