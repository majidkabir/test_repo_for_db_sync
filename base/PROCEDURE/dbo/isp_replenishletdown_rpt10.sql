SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_ReplenishLetdown_rpt10                              */
/* Creation Date: 30-JUL-2019                                           */
/* Copyright: LF Logistics                                              */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose: WMS-9885 - CN UA B2B backup solution Release wave Report    */
/*        :                                                             */
/* Called By:                                                           */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/************************************************************************/
CREATE PROC [dbo].[isp_ReplenishLetdown_rpt10]
           @c_Loadkey       NVARCHAR(20)

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
	  @c_ExecStatements   NVARCHAR(4000),    
      @c_ExecArguments    NVARCHAR(4000)

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

   CREATE TABLE #TMP_REPLEN10RPT
     (   facility       NVARCHAR(20)
	  ,  loadkey        NVARCHAR(20)
      ,  Storerkey      NVARCHAR(15)
      ,  Sku            NVARCHAR(20)
	  ,  Wavekey        NVARCHAR(10)
      ,  FromLoc        NVARCHAR(10)
      ,  ToLoc          NVARCHAR(10)   
	  ,  Dropid         NVARCHAR(20)
      ,  ReplenGrp      NVARCHAR(10)
      ,  CaseCnt        FLOAT
      ,  Qty            INT
      ,  casepick       INT
      )


   WHILE @@TRANCOUNT > 0
   BEGIN
      COMMIT TRAN
   END

   SET @c_SQLInsert ='INSERT INTO #TMP_REPLEN10RPT (Storerkey,Sku,facility,FromLoc,ToLoc,loadkey,Wavekey,ReplenGrp,CaseCnt,Qty,dropid,casepick) ' 

   IF EXISTS (SELECT 1 FROM replenishment RP WITH (nolock)
              WHERE wavekey = @c_Loadkey )
   BEGIN
       SET @c_condition1 = N' WHERE RP.wavekey = @c_Loadkey '
   END
   ELSE IF EXISTS (SELECT 1 FROM ORDERS WITH (NOLOCK)
                   WHERE Loadkey = @c_Loadkey)
  BEGIN
     SET @c_condition1 = N' WHERE ORD.loadkey = @c_Loadkey '
  END
  ELSE
  BEGIN
     GOTO QUIT_SP
  END

    SET @c_SQLOrdBy = N' ORDER BY RP.sku '
    SET @c_SQLGroup = ' GROUP BY ORD.storerkey,RP.wavekey,RP.ReplenishmentGroup,RP.Fromloc,RP.SKU,RP.refno,P.casecnt,RP.toloc,RP.qty '

    SET @c_SQLJOIN = N'SELECT ORD.storerkey,RP.SKU,MAX(ORD.Facility),RP.Fromloc,RP.toloc,MAX(ORD.loadkey),RP.wavekey,RP.ReplenishmentGroup,P.casecnt '
					+',RP.qty,RP.refno,FLOOR(RP.qty/P.casecnt) '
					+'FROM replenishment RP WITH (nolock) '
					+'JOIN WAVE WV WITH (NOLOCK) ON WV.Wavekey = RP.Wavekey '
					+'JOIN WAVEDETAIL WDET WITH (NOLOCK) ON WDET.wavekey = WV.wavekey '
					+'JOIN ORDERDETAIL OD WITH (NOLOCK) ON OD.Orderkey = WDET.orderkey '
					+'JOIN ORDERS ORD WITH (NOLOCK) ON ORD.orderkey = OD.orderkey '
					+'JOIN PACK P WITH (NOLOCK) ON P.Packkey = RP.Packkey '


   SET @c_SQL = @c_SQLInsert + CHAR(13) + @c_SQLJOIN  + CHAR(13) + @c_condition1 + CHAR(13) + @c_SQLGroup + CHAR(13) +  @c_SQLOrdBy
  
   SET @c_ExecArguments = N'   @c_Loadkey           NVARCHAR(80)' 
                    
   EXEC sp_ExecuteSql     @c_SQL     
                        , @c_ExecArguments    
                        , @c_Loadkey    


QUIT_SP:

   SELECT * FROM #TMP_REPLEN10RPT

   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END
END -- procedure

GO