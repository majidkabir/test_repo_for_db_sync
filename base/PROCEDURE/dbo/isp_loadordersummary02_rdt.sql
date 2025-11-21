SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* S Proc: isp_LoadOrderSummary02_rdt                                   */
/* Creation Date: 23/12/2019                                            */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose:                                                             */
/* Input Parameters: Loadkey                                            */
/*                                                                      */
/* Output Parameters: None                                              */
/*                                                                      */
/* Return Status: None                                                  */
/*                                                                      */
/* Usage: WMS-11520 - CN_REMY WECHAT_WMS_Move Report                    */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By: r_dw_load_order_summary_02_rdt                            */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/************************************************************************/

CREATE PROC [dbo].[isp_LoadOrderSummary02_rdt]
     @c_LoadKey     NVARCHAR(10), @c_type NVARCHAR(10) = ''

AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @b_Success        INT
         , @n_Err            INT
         , @n_Continue       INT
         , @n_StartTCnt      INT
         , @c_ErrMsg         NVARCHAR(250)
         , @c_UserId         NVARCHAR(30)
         , @n_cnt            INT
         , @c_Getprinter     NVARCHAR(10) 
         , @c_GetDatawindow  NVARCHAR(50) = 'r_dw_load_order_summary_02_rdt'
         , @c_ReportID       NVARCHAR(10) = 'LPREPLEN'
         , @c_Storerkey      NVARCHAR(15)

   SET @b_Success   = 1
   SET @n_Err       = 0
   SET @n_Continue  = 1
   SET @n_StartTCnt = @@TRANCOUNT
   SET @c_ErrMsg    = ''
   SET @c_UserId    = SUSER_SNAME()

   WHILE @@TRANCOUNT > 0
   BEGIN
      COMMIT TRAN
   END

   SELECT @c_Storerkey = MAX(OH.Storerkey)
   FROM LOADPLANDETAIL LPD (NOLOCK)
   JOIN ORDERS OH (NOLOCK) ON OH.ORDERKEY = LPD.ORDERKEY
   WHERE LPD.LOADKEY = @c_LoadKey
   
   SELECT @c_Getprinter = defaultprinter  
   FROM RDT.RDTUser AS r WITH (NOLOCK)  
   WHERE r.UserName = @c_UserId  

   --SET @c_Getprinter = 'Chooi02'

   IF @c_type = NULL SET @c_type = ''
   
   IF @c_type = ''
   BEGIN
      BEGIN TRAN                            
      EXEC isp_PrintToRDTSpooler   
           @c_ReportType     = @c_ReportID,   --UCCLbConso 10 CHARS
           @c_Storerkey      = @c_Storerkey,  --18491'
           @b_success        = @b_success OUTPUT,  
           @n_err            = @n_err     OUTPUT,  
           @c_errmsg         = @c_errmsg  OUTPUT,  
           @n_Noofparam      = 2,  --2
           @c_Param01        = @c_LoadKey,  
           @c_Param02        = 'H1',  
           @c_Param03        = '',  
           @c_Param04        = '',  
           @c_Param05        = '',  
           @c_Param06        = '',  
           @c_Param07        = '',  
           @c_Param08        = '',  
           @c_Param09        = '',  
           @c_Param10        = '',  
           @n_Noofcopy       = 1,  
           @c_UserName       = @c_UserId,    --suser_sname()
           @c_Facility       = '',  
           @c_PrinterID      = @c_Getprinter,  --Printer from RDT.RDTUser
           @c_Datawindow     = @c_GetDatawindow,  --Datawindow name
           @c_IsPaperPrinter = 'Y'
   
      IF @b_success <> 1
      BEGIN
         ROLLBACK TRAN
         GOTO QUIT_SP
      END  
   
      WHILE @@TRANCOUNT > 0  
      BEGIN  
         COMMIT TRAN  
      END  

      SELECT NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'Printing Completed'
   END
   ELSE
   BEGIN   
      SELECT CONVERT(NVARCHAR(10),GETDATE(),120) + ' ' + N'人头马微商城移库单' AS Title
           , LPD.Loadkey
           , SKU.SKU
           , SKU.Descr
           , PACK.Casecnt AS PK
           , LLI.Loc AS FromLoc
           , SUM(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked) AS RemainingQty
           , SUM(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked) AS MoveQty
           , 0 AS QtyAfterMoving
           , OH.Storerkey AS Storerkey
           , '' AS Remark
      INTO #TEMP_MOVE
      FROM LOADPLANDETAIL LPD (NOLOCK)
      JOIN ORDERS OH (NOLOCK) ON OH.Orderkey = LPD.Orderkey
      JOIN PICKDETAIL PD (NOLOCK) ON PD.Orderkey = LPD.Orderkey
      JOIN LOC (NOLOCK) ON LOC.LOC = PD.LOC
      JOIN LOTxLOCxID LLI (NOLOCK) ON PD.LOT = LLI.LOT AND PD.LOC = LLI.LOC AND PD.ID = LLI.ID
      JOIN SKU (NOLOCK) ON PD.SKU = SKU.SKU AND PD.STORERKEY = SKU.STORERKEY
      JOIN PACK (NOLOCK) ON SKU.PACKKEY = PACK.PACKKEY
      WHERE LOC.LocationCategory = 'MOVE' 
        AND LPD.Loadkey = @c_LoadKey
      GROUP BY SKU.SKU, SKU.Descr, PACK.Casecnt, LLI.Loc, LPD.Loadkey, OH.Storerkey
      HAVING SUM(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked) < PACK.CASECNT
         AND SUM(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked) > 0

      SELECT Title, Loadkey, SKU, Descr, PK, FromLoc, RemainingQty, MoveQty, QtyAfterMoving, SL.Loc AS ToLoc, Remark FROM #TEMP_MOVE t
      CROSS APPLY (SELECT TOP 1 SL.Loc FROM SKUxLOC SL (NOLOCK) 
                   JOIN LOC (NOLOCK) ON SL.LOC = LOC.LOC
                   WHERE SL.SKU = t.SKU AND LOC.LocationCategory = 'OTHER' AND SL.StorerKey = t.Storerkey) AS SL
   END


   QUIT_SP:
   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END

   IF OBJECT_ID('tempdb..#TEMP_MOVE') IS NOT NULL
      DROP TABLE #TEMP_MOVE
END

GO