SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: ispPONIK01                                         */
/* Creation Date: 28-Feb-2017                                           */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-1106 - CN-Nike SDC WMS Allocation Strategy              */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 30-Jun-2017 Wan01    1.1   WMS-2295 - CN-Nike SDC WMS Allocation     */
/*                            Strategy CR                               */
/************************************************************************/
CREATE  PROC [dbo].[ispPONIK01]
    @c_WaveKey                      NVARCHAR(10)
  , @c_UOM                          NVARCHAR(10)
  , @c_LocationTypeOverride         NVARCHAR(10)
  , @c_LocationTypeOverRideStripe   NVARCHAR(10)
  , @b_Success                      INT           OUTPUT  
  , @n_Err                          INT           OUTPUT  
  , @c_ErrMsg                       NVARCHAR(250) OUTPUT  
  , @b_Debug                        INT = 0  
AS    
BEGIN    
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET ANSI_NULLS OFF    

   DECLARE @n_Continue        INT   
         , @n_StartTCnt       INT 
         , @b_UpdateUCC       INT 

   DECLARE @c_PickDetailKey   NVARCHAR(10) 
         , @c_Orderkey        NVARCHAR(10) 
         , @c_OrderLineNumber NVARCHAR(5) 
         , @c_StorerKey       NVARCHAR(15) 
         , @c_SKU             NVARCHAR(20) 
         , @c_Lot             NVARCHAR(10)      
         , @c_Loc             NVARCHAR(10) 
         , @c_ID              NVARCHAR(18) 
         , @n_Qty             INT

         , @n_UCC_RowRef      INT
         , @n_UCCQty          INT
         , @c_UCCNo           NVARCHAR(20)

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue=1
   SET @b_Success=1
   SET @n_Err=0
   SET @c_ErrMsg=''

  
   IF EXISTS ( SELECT 1
               FROM WAVE WITH (NOLOCK)
               WHERE Wavekey = @c_Wavekey
               AND DispatchPiecePickMethod NOT IN ('INLINE', 'DTC')  --(Wan01)
             )
   BEGIN  
      --SET @c_ErrMsg = 'Invalid Wave Piece Pick Task Dispatch Method. Must Be INLINE/ECOM (ispPONIK01)'
      GOTO QUIT_SP
   END

   DECLARE CUR_UCCPICK CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
   SELECT
       PD.Lot
     , PD.Loc
     , PD.ID
     , Qty = SUM(PD.Qty)
   FROM PICKDETAIL PD WITH (NOLOCK)
   JOIN LOC WITH (NOLOCK) ON (PD.Loc = LOC.LOC)    
   JOIN WAVEDETAIL WD WITH (NOLOCK) ON (PD.OrderKey =WD.OrderKey)
   WHERE WD.WaveKey = @c_WaveKey
      AND LOC.LocationCategory = 'BULK'
      AND LOC.LocationType = 'OTHER'
      AND ISNULL(PD.DropID, '') = ''
      AND PD.UOM = '7' 
   GROUP BY PD.Lot
        ,   PD.Loc
        ,   PD.ID
   ORDER BY PD.Lot
        ,   PD.Loc
        ,   PD.ID

   OPEN CUR_UCCPICK
   FETCH NEXT FROM CUR_UCCPICK INTO @c_Lot
                                 ,  @c_Loc
                                 ,  @c_ID
                                 ,  @n_Qty
          
   WHILE (@@FETCH_STATUS <> -1)          
   BEGIN 
      SET @c_UCCNo = ''
      SET @n_UCCQty = 0

      SELECT TOP 1 @n_UCC_RowRef = UCC_RowRef
                  ,@c_UCCNo = UCCNo
                  ,@n_UCCQty= Qty
      FROM UCC WITH (NOLOCK)
      WHERE Lot = @c_Lot
      AND   Loc = @c_Loc
      AND   ID  = @c_ID
      AND   Qty >=@n_Qty
      AND   Status < '3'
      ORDER BY Qty, UCC_RowRef

      IF @c_UCCNo = ''
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 61020
         SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0)) 
                       + ': UCC # Not Found. (ispPONIK01)'
         GOTO QUIT_SP
      END

      SET @b_UpdateUCC = 1
      DECLARE CUR_PICK CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
      SELECT
          PD.PickDetailKey
        , PD.Orderkey
        , PD.OrderLineNumber  
      FROM PICKDETAIL PD WITH (NOLOCK)
      JOIN WAVEDETAIL WD WITH (NOLOCK) ON (PD.OrderKey =WD.OrderKey)
      WHERE WD.WaveKey = @c_WaveKey
         AND Lot = @c_Lot
         AND Loc = @c_Loc
         AND ID  = @c_ID
         AND ISNULL(PD.DropID, '') = ''
         AND PD.UOM = '7' 

      OPEN CUR_PICK
      FETCH NEXT FROM CUR_PICK INTO @c_PickDetailKey
                                 ,  @c_Orderkey
                                 ,  @c_OrderLineNumber
          
      WHILE (@@FETCH_STATUS <> -1)          
      BEGIN 
         UPDATE PICKDETAIL WITH (ROWLOCK)
         SET DropID = @c_UCCNo
            ,UOMQty = @n_UCCQty
            ,EditWho= SUSER_NAME()
            ,EditDate = GETDATE() 
            ,Trafficcop = NULL
         WHERE PickDetailKey = @c_PickDetailKey

         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3
            SET @n_Err = 61020
            SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0)) 
                          + ': Update PickDetail Failed. (ispPONIK01)'
            GOTO QUIT_SP
         END

         IF @b_UpdateUCC = 1
         BEGIN
            UPDATE UCC WITH (ROWLOCK)
            SET Status = '3'
               ,PickDetailKey = @c_PickDetailKey
               ,Orderkey = @c_Orderkey
               ,OrderLineNumber = @c_OrderLineNumber
            WHERE UCC_RowRef = @n_UCC_RowRef

            IF @@ERROR <> 0
            BEGIN
               SET @n_Continue = 3
               SET @n_Err = 61030
               SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0)) 
                              + ': Update UCC Failed. (ispPONIK01)'
               GOTO QUIT_SP
            END

            SET @b_UpdateUCC = 0
         END

         FETCH NEXT FROM CUR_PICK INTO @c_PickDetailKey
                                    ,  @c_Orderkey
                                    ,  @c_OrderLineNumber
      END
      CLOSE CUR_PICK
      DEALLOCATE CUR_PICK

      FETCH NEXT FROM CUR_UCCPICK INTO @c_Lot
                                    ,  @c_Loc
                                    ,  @c_ID
                                    ,  @n_Qty
   END
   CLOSE CUR_UCCPICK
   DEALLOCATE CUR_UCCPICK

   QUIT_SP:
   IF CURSOR_STATUS( 'LOCAL', 'CUR_UCCPICK') in (0 , 1)  
   BEGIN
      CLOSE CUR_UCCPICK           
      DEALLOCATE CUR_UCCPICK      
   END 

   IF CURSOR_STATUS( 'LOCAL', 'CUR_PICK') in (0 , 1)  
   BEGIN
      CLOSE CUR_PICK           
      DEALLOCATE CUR_PICK      
   END 
   
  IF @n_Continue=3  -- Error Occured - Process And Return  
   BEGIN  
      SELECT @b_Success = 0  
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt  
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
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'ispPONIK01'  
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
      RETURN  
   END  
   ELSE  
   BEGIN  
      SELECT @b_Success = 1  
      WHILE @@TRANCOUNT > @n_StartTCnt  
      BEGIN  
         COMMIT TRAN  
      END  
      RETURN  
   END      
END -- Procedure

GO