SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_replenishment_rpt                                   */
/* Creation Date: 07-NOV-2019                                           */
/* Copyright: LF Logistics                                              */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose: WMS-10949 - CN NIVEAWGQ Replenishment Report                */
/*                                                                      */
/* Called By: r_replenishment_rpt                                       */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/************************************************************************/
CREATE PROC [dbo].[isp_replenishment_rpt]
           @c_ReplenishmentKey       NVARCHAR(20) = ''
          ,@c_refno                  NVARCHAR(20) = ''

AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt          INT
         , @n_Continue           INT 
         , @c_ReplenGrpList      NVARCHAR(1000)
         , @c_ToLoc              NVARCHAR(10)

DECLARE                     
      @c_SQL             NVARCHAR(4000),        
      @c_SQLSORT         NVARCHAR(4000),        
      @c_SQLJOIN         NVARCHAR(4000),
      @c_condition1      NVARCHAR(150) ,
      @c_condition2      NVARCHAR(150),
      @c_SQLGroup        NVARCHAR(4000),
      @c_SQLOrdBy        NVARCHAR(150),
      @c_SQLinsert       NVARCHAR(4000) ,  
      @c_SQLSelect       NVARCHAR(4000),
      @c_ExecStatements  NVARCHAR(4000),    
      @c_ExecArguments   NVARCHAR(4000)

   SET @n_StartTCnt = @@TRANCOUNT
   SET @c_SQL = ''    
   SET @c_SQLJOIN = ''        
   SET @c_condition1 = ''
   SET @c_condition2= ''
   SET @c_SQLOrdBy = ''
   SET @c_SQLGroup = ''
   SET @c_ExecStatements = ''
   SET @c_ExecArguments = ''
   SET @c_SQLinsert = ''
   SET @c_SQLSelect = ''

   CREATE TABLE #TMP_REPLENRPT01
     (   refno          NVARCHAR(20)
      ,  lottable02     NVARCHAR(20)
      ,  Storerkey      NVARCHAR(15)
      ,  Sku            NVARCHAR(20)
      ,  lottable03     NVARCHAR(20)
      ,  FromLoc        NVARCHAR(10)
      ,  SDESCR         NVARCHAR(200)  
      ,  id             NVARCHAR(20)
      ,  CaseCnt        FLOAT
      ,  Qty            INT
      ,  qtyreplen      INT
      ,  grpid          INT
      )


   WHILE @@TRANCOUNT > 0
   BEGIN
      COMMIT TRAN
   END

   SET @c_SQLInsert ='INSERT INTO #TMP_REPLENRPT01 (refno,lottable02,Storerkey,Sku,lottable03,FromLoc,SDESCR,id,CaseCnt,Qty,qtyreplen,grpid) ' 

   IF ISNULL(@c_ReplenishmentKey,'') <> '' AND ISNULL(@c_refno,'') = ''
   BEGIN
       SET @c_condition1 = N' WHERE RP.ReplenishmentKey = @c_ReplenishmentKey '
   END
   ELSE IF ISNULL(@c_ReplenishmentKey,'') = '' AND ISNULL(@c_refno,'') <> ''
   BEGIN
     SET @c_condition1 = N' WHERE RP.refno = @c_refno '
   END
   ELSE IF ISNULL(@c_ReplenishmentKey,'') <> '' AND ISNULL(@c_refno,'') <> ''
   BEGIN
     SET @c_condition1 = N' WHERE RP.ReplenishmentKey = @c_ReplenishmentKey AND RP.refno = @c_refno '
   END
   ELSE
   BEGIN
     GOTO QUIT_SP
   END

    SET @c_SQLOrdBy = N' ORDER BY RP.refno,RP.sku,LOTT.lottable02,RP.fromloc '
    SET @c_SQLGroup = ' GROUP BY RP.refno,RP.SKU,S.descr,P.casecnt,RP.fromloc,LOTT.lottable02,LOTT.lottable03,RP.Storerkey,rp.lot '

    SET @c_SQLJOIN = N'SELECT RP.refno,LOTT.lottable02,RP.Storerkey,RP.SKU,LOTT.lottable03,RP.fromloc,S.descr,rp.lot,P.casecnt,sum(RP.qty) as Rqty '
                   +' ,sum(LLI.Qty-LLI.QtyAllocated-LLI.QtyPicked-LLI.QtyReplen) qtyreplen ' 
                   + ',row_number() over(partition by RP.SKU ,LOTT.lottable02 ORDER by RP.refno,RP.sku,LOTT.lottable02,RP.fromloc)'
                   +'FROM replenishment RP WITH (nolock) '
                   +'JOIN SKU S WITH (NOLOCK) ON S.SKU = RP.Sku and S.Storerkey = RP.Storerkey '
                   +'JOIN LOTATTRIBUTE LOTT WITH (NOLOCK) ON LOTT.lot = RP.lot and LOTT.sku = RP.SKU '
                   +'JOIN LOTXLOCXID LLI WITH (NOLOCK) ON LLI.lot = RP.lot AND LLI.sku = RP.sku and LLI.LOC = RP.fromloc and LLI.ID=RP.id '
                   +'JOIN PACK P WITH (NOLOCK) ON P.Packkey = RP.Packkey '


   SET @c_SQL = @c_SQLInsert + CHAR(13) + @c_SQLJOIN  + CHAR(13) + @c_condition1 + CHAR(13) + @c_SQLGroup + CHAR(13) +  @c_SQLOrdBy
  
   SET @c_ExecArguments = N'   @c_ReplenishmentKey           NVARCHAR(20)'
                          + ' ,@c_refno                      NVARCHAR(20) '  
                    
   EXEC sp_ExecuteSql     @c_SQL     
                        , @c_ExecArguments    
                        , @c_ReplenishmentKey  
                        , @c_refno  


QUIT_SP:

   SELECT * FROM #TMP_REPLENRPT01
   ORDER BY refno,sku,lottable02,grpid

   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END
END -- procedure

GO