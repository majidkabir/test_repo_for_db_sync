SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: msp_RCM_WV_ULP_StockOwnerChange                         */
/* Creation Date: 2024-09-30                                            */
/* Copyright: Maersk Logistics                                          */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: UWP-23788 - Stock Owner Change Without Physical Move        */
/*        :                                                             */
/* Called By:                                                           */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 8.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 2024-09-30  Wan      1.0   Created.                                  */
/* 2024-11-14  Wan01    1.1   Fixed to loc pendingmove when qtypicked=qty*/
/************************************************************************/
CREATE   PROC msp_RCM_WV_ULP_StockOwnerChange
   @c_Wavekey  NVARCHAR(10)
,  @b_success  INT          = 1  OUTPUT
,  @n_err      INT          = 0  OUTPUT
,  @c_errmsg   NVARCHAR(225)= '' OUTPUT
,  @c_code     NVARCHAR(30) = ''
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE
           @n_StartTCnt          INT   = @@TRANCOUNT
         , @n_Continue           INT   = 1

         , @n_WarningNo          INT          = 0
         , @n_ErrGroupKey        INT          = 0
         , @c_ProceedWithWarning CHAR(1)      = 'N'
         , @c_UserName           NVARCHAR(128)= SUSER_SNAME()
         , @b_PopupWindow        INT	= 0
         , @n_NoOfOrderNoLoad    INT	= 0
         , @c_BuildParmKeys     NVARCHAR(2000)=''

         , @c_Orderkey			 NVARCHAR(10) = ''
         , @c_Storerkey          NVARCHAR(15) = ''
         , @c_Sku                NVARCHAR(20) = ''
         , @c_Lot                NVARCHAR(10) = ''
         , @c_Loc                NVARCHAR(10) = ''
         , @c_ID                 NVARCHAR(18) = ''
         , @n_Qty                INT          = 0

         , @CUR_PD               CURSOR
		 , @CUR_OK               CURSOR

   SET @b_success = 1
   SET @n_err     = 0
   SET @c_errmsg  = ''

   IF EXISTS ( SELECT 1 FROM WAVEDETAIL wd (NOLOCK)
               JOIN ORDERS oh (NOLOCK) ON oh.orderkey = wd.orderkey
               WHERE wd.Wavekey = @c_Wavekey
               AND oh.[Type] <> 'PI'                       --changed from OBD to PI
             )
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 68010
      SET @c_ErrMsg = 'NSQL'+ CONVERT(NVARCHAR(5), @n_Err)
                    + ': None PI Shipment Order type found. (msp_RCM_WV_ULP_StockOwnerChange)'
      GOTO QUIT_SP
   END

   IF NOT EXISTS ( SELECT 1 FROM WAVEDETAIL wd (NOLOCK)
               JOIN ORDERS oh (NOLOCK) ON oh.orderkey = wd.orderkey
               WHERE wd.Wavekey = @c_Wavekey
               AND Exists (select 1 from CODELKUP where LISTNAME='VENDORCODE' and UDF01=oh.C_Company)
             )
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 68010
      SET @c_ErrMsg = 'NSQL'+ CONVERT(NVARCHAR(5), @n_Err)
                    + ': Company name does not match with codeluk up. (msp_RCM_WV_ULP_StockOwnerChange)'
      GOTO QUIT_SP
   END


   IF EXISTS ( SELECT 1 FROM WAVEDETAIL wd (NOLOCK)
               JOIN ORDERS oh (NOLOCK) ON oh.orderkey = wd.orderkey
               WHERE wd.Wavekey = @c_Wavekey
               AND oh.[Status] = '0'
             )
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 68120
      SET @c_ErrMsg = 'NSQL'+ CONVERT(NVARCHAR(5), @n_Err)
                    + ': Open Shipment Orders found. (msp_RCM_WV_ULP_StockOwnerChange)'
      GOTO QUIT_SP
   END

   EXEC [WM].[lsp_WaveGenLoadPlan]
          @c_WaveKey  = @c_WaveKey
   ,  @b_Success	  = @b_Success  OUTPUT
   ,  @n_err          = @n_err      OUTPUT
   ,  @c_ErrMsg       = @c_ErrMsg   OUTPUT
   ,  @c_UserName     = ''
   ,  @b_PopupWindow        = @b_PopupWindow           OUTPUT
   ,  @n_NoOfOrderNoLoad    = @n_NoOfOrderNoLoad           OUTPUT
   ,  @c_BuildParmKeys      =''

   IF @b_Success = 0
   BEGIN
      SET @n_Continue = 3
      GOTO QUIT_SP
   END

   EXEC [WM].[lsp_WaveGenMBOL]
      @c_WaveKey  = @c_WaveKey
   ,  @b_Success  = @b_Success  OUTPUT
   ,  @n_err      = @n_err      OUTPUT
   ,  @c_ErrMsg   = @c_ErrMsg   OUTPUT
   ,  @c_UserName = ''

   IF @b_Success = 0
   BEGIN
      SET @n_Continue = 3
      GOTO QUIT_SP
   END

      SET @CUR_OK = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT OrderKey from WAVEDETAIL
   where WaveKey=@c_WaveKey

   OPEN @CUR_OK

   FETCH NEXT FROM @CUR_OK INTO @c_Orderkey

   WHILE @@FETCH_STATUS <> -1 AND @n_Continue IN (1,2)
   BEGIN
   Update orders
   set [Status]='5', TrafficCop=NULL
   where OrderKey=@c_Orderkey and [status] < '5'

   Update orderdetail
   set [Status]='5', TrafficCop=NULL
   where OrderKey=@c_Orderkey and [status] < '5'

      FETCH NEXT FROM @CUR_OK INTO @c_Orderkey
   END
   CLOSE @CUR_OK
   DEALLOCATE @CUR_OK


SET @CUR_PD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT pd.Storerkey
         ,pd.Sku
         ,pd.Lot
         ,pd.Loc
         ,pd.ID
         ,Qty = ISNULL(SUM(pd.Qty),0)
   FROM WAVEDETAIL wd (NOLOCK)
   JOIN PICKDETAIL pd (NOLOCK) ON pd.orderkey = wd.orderkey
   LEFT OUTER JOIN RFPUTAWAY rpa (NOLOCK) ON  rpa.lot = pd.lot
                                          AND rpa.SuggestedLoc = pd.loc
                                          AND rpa.id  = pd.id
   WHERE wd.Wavekey = @c_Wavekey
   AND rpa.storerkey IS NULL
   GROUP BY pd.Storerkey
         ,  pd.Sku
         ,  pd.Lot
         ,  pd.Loc
         ,  pd.ID
   ORDER BY MIN(pd.pickdetailkey)

   OPEN @CUR_PD

   FETCH NEXT FROM @CUR_PD INTO @c_Storerkey
                              , @c_Sku
                              , @c_Lot
                              , @c_Loc
                              , @c_ID
                              , @n_Qty

   WHILE @@FETCH_STATUS <> -1 AND @n_Continue IN (1,2)
   BEGIN
      SET @n_Err = 0
      EXEC rdt.rdt_Putaway_PendingMoveIn
         @cUserName        = ''
      ,  @cType            = 'LOCK'
      ,  @cFromLoc         = @c_LOC
      ,  @cFromID          = @c_ID
      ,  @cSuggestedLOC    = @c_Loc
      ,  @cStorerKey       = @c_Storerkey
      ,  @nErrNo           = @n_Err       OUTPUT
      ,  @cErrMsg          = @c_Errmsg    OUTPUT
      ,  @cSKU             = @c_SKU
      ,  @nPutawayQTY      = @n_Qty
      ,  @cFromLOT         = @c_Lot
      ,  @cTaskDetailKey   = ''
      ,  @nFunc            = 0
      ,  @nPABookingKey    = 0
      ,  @cMoveQTYAlloc    = '1'
      ,  @cMoveQTYPick     = '1'         --2024-11-14 - Fixed.
      ,  @cMoveQTYReplen   = '1'

      IF @n_err <> 0
      BEGIN
         SET @n_continue = 3
         GOTO QUIT_SP
      END

      FETCH NEXT FROM @CUR_PD INTO @c_Storerkey
                                 , @c_Sku
                                 , @c_Lot
                                 , @c_Loc
                                 , @c_ID
                                 , @n_Qty
   END
   CLOSE @CUR_PD
   DEALLOCATE @CUR_PD

   WHILE @n_Continue = 1
   BEGIN
      SET @n_ErrGroupKey = 0
      EXEC [WM].[lsp_WaveShip]
         @c_WaveKey              = @c_WaveKey
      ,  @c_MBOLkey              = ''
      ,  @c_ShipMode             = 'WAVE'
      ,  @n_TotalSelectedKeys    = 1
      ,  @n_KeyCount             = 0
      ,  @b_Success              = @b_Success      OUTPUT
      ,  @n_err                  = @n_err          OUTPUT
      ,  @c_ErrMsg               = @c_ErrMsg       OUTPUT
      ,  @n_WarningNo            = @n_WarningNo    OUTPUT
      ,  @c_ProceedWithWarning   = @c_ProceedWithWarning
      ,  @c_UserName             = @c_UserName
      ,  @n_ErrGroupKey          = @n_ErrGroupKey  OUTPUT

      SELECT TOP 1 @c_ErrMsg = ErrMsg FROM WM.WMS_Error_List (NOLOCK)
      WHERE ErrGroupKey = @n_ErrGroupKey
      AND WriteType = 'ERROR'
      AND SourceType = 'lsp_WaveShip'

      IF @@ROWCOUNT > 0
      BEGIN
         SET @n_Continue = 3
         GOTO QUIT_SP
      END

      IF (@c_ProceedWithWarning='Y')
        BEGIN
         break
        ENd

      SET @c_ProceedWithWarning = 'Y'

   END



QUIT_SP:
   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_Success = 0
      IF  @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'msp_RCM_WV_ULP_StockOwnerChange'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END
END -- procedure

GO