SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_ptlpiece_ikea_rpt_rdt                               */
/* Creation Date: 28-JUL-2020                                           */
/* Copyright: LF Logistics                                              */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose: WMS-14342 - [CN] IKEA_PTL Piece report                      */
/*        :                                                             */
/* Called By: r_dw_ptlpiece_ikea_rpt_rdt                                */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver Purposes                                  */
/************************************************************************/
CREATE PROC [dbo].[isp_ptlpiece_ikea_rpt_rdt]
           @c_sourceKey   NVARCHAR(20)

AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt       INT
         , @n_Continue        INT 


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


   IF ISNULL(@c_sourceKey,'') = ''
   BEGIN
      GOTO QUIT_SP
   END

   SET @n_StartTCnt = @@TRANCOUNT

   WHILE @@TRANCOUNT > 0
   BEGIN
      COMMIT TRAN
   END
  
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

   CREATE TABLE #TMP_PTLPRDT
      (  RowID          INT IDENTITY (1,1) NOT NULL 
      ,  Orderkey       NVARCHAR(20)   NULL  DEFAULT('')
      ,  Pickslipno     NVARCHAR(10)   NULL  DEFAULT('')
      ,  DevicePosition NVARCHAR(10)   NULL  DEFAULT('')
      ,  PQty           INT            NULL  DEFAULT(0)
      ,  SKUCnt         INT            NULL  DEFAULT(0)
     )

           
   SET @c_SQLinsert = N'INSERT INTO #TMP_PTLPRDT(Orderkey,Pickslipno,DevicePosition,PQty,SKUCnt) '
 
 
   SET @c_SQLSelect = N'SELECT oh.orderkey,pid.pickslipno,ISNULL(DevP.DevicePosition,''''),sum(pid.qty),count(DISTINCT PID.sku) ' + CHAR(13) +
                         ' FROM PICKDETAIL PID WITH (NOLOCK) ' + CHAR(13) +
                         ' JOIN ORDERS  OH WITH (NOLOCK) ON ( OH.OrderKey = PID.orderkey AND OH.storerkey = PID.storerkey ) ' + CHAR(13) +  
                         ' JOIN LOC l WITH (NOLOCK) ON ( l.loc = pid.loc ) ' + CHAR(13) + 
                         ' LEFT JOIN rdt.rdtPTLPieceLog  PTLLOG WITH (NOLOCK)   ON ( PTLLOG.orderkey = OH.Orderkey ) ' + CHAR(13) + 
                         ' LEFT JOIN DeviceProfile  DevP WITH (NOLOCK) ON (DevP.DeviceID  = PTLLOG.station AND DevP.deviceposition=PTLLOG.Position)' 
                        --WHERE ( MBOL.Mbolkey = @c_MBOLKey ) 
    
    IF EXISTS (SELECT 1 FROM ORDERS OH WITH (NOLOCK) WHERE OH.orderkey = @c_sourceKey )
    BEGIN
      SET @c_condition1 = ' WHERE OH.orderkey = @c_sourceKey '  
    END
    ELSE IF EXISTS (SELECT 1 FROM PICKDETAIL PID WITH (NOLOCK) WHERE PID.Pickslipno = @c_sourceKey )
    BEGIN
      SET @c_condition1 = ' WHERE PID.Pickslipno = @c_sourceKey '  
    END

   IF ISNULL(@c_condition1,'') = ''
   BEGIN
      GOTO QUIT_SP
   END

   SET @c_SQLGroup = N' GROUP BY oh.Orderkey,pid.pickslipno,ISNULL(DevP.DevicePosition,'''') '
   SET @c_SQLOrdBy = N' Order BY oh.Orderkey,pid.pickslipno,ISNULL(DevP.DevicePosition,'''') '

    SET @c_SQL = @c_SQLinsert + CHAR(13) + @c_SQLSelect + CHAR(13) + @c_condition1 + CHAR(13) + @c_SQLGroup + CHAR(13) + @c_SQLOrdBy

   --PRINT @c_SQL
   SET @c_ExecArguments = N'@c_sourceKey           NVARCHAR(20)'                          
                         
   EXEC sp_ExecuteSql     @c_SQL     
                        , @c_ExecArguments    
                        , @c_sourceKey
  
   SELECT Orderkey,Pickslipno,DevicePosition,PQty,SKUCnt
   FROM #TMP_PTLPRDT 
   
 QUIT_SP:

 WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END
       
END -- procedure

GO