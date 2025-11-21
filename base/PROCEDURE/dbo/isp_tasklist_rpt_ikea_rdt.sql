SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_tasklist_rpt_ikea_rdt                               */
/* Creation Date: 29-JUL-2020                                           */
/* Copyright: LF Logistics                                              */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose: WMS-14340 - [CN] IKEA_Tasklist_Report                       */
/*        :                                                             */
/* Called By: r_dw_tasklist_rpt_ikea_rdt                                */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver Purposes                                  */
/************************************************************************/
CREATE PROC [dbo].[isp_tasklist_rpt_ikea_rdt]
           @c_sourcekey   NVARCHAR(20)

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


   IF ISNULL(@c_sourcekey,'') = ''
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

   CREATE TABLE #TMP_TLISTRPTIKEARDT
      (  RowID         INT IDENTITY (1,1) NOT NULL 
      ,  loadKey        NVARCHAR(20)   NULL  DEFAULT('')
      ,  Pickslipno     NVARCHAR(10)   NULL  DEFAULT('')
      ,  PickZone       NVARCHAR(10)   NULL  DEFAULT('')
      ,  PQty           INT            NULL  DEFAULT(0)
     )

           
   SET @c_SQLinsert = N'INSERT INTO #TMP_TLISTRPTIKEARDT(loadkey,Pickslipno,PickZone,PQty) '
 
 
   SET @c_SQLSelect = N'SELECT oh.loadkey,pid.pickslipno,l.pickzone,sum(pid.qty) ' + CHAR(13) +
                         ' FROM PICKDETAIL PID WITH (NOLOCK) ' + CHAR(13) +
                         ' JOIN ORDERS  OH WITH (NOLOCK) ON ( OH.OrderKey = PID.orderkey AND OH.storerkey = PID.storerkey ) ' + CHAR(13) +  
                         ' JOIN LOC l WITH (NOLOCK) ON ( l.loc = pid.loc )   ' 
   --JOIN rdt.rdtPTLPieceLog  PTLLOG WITH (NOLOCK)   ON ( PTLLOG.orderkey = OH.Orderkey )
 --  JOIN DeviceProfile  DevP WITH (NOLOCK) ON (DevP.DeviceID  = PTLLOG.station)
                        --WHERE ( MBOL.Mbolkey = @c_MBOLKey ) 
    
    IF EXISTS (SELECT 1 FROM ORDERS OH WITH (NOLOCK) WHERE OH.loadkey = @c_sourcekey )
    BEGIN
      SET @c_condition1 = ' WHERE OH.Loadkey = @c_sourcekey '  
    END
    ELSE IF EXISTS (SELECT 1 FROM PICKDETAIL PID WITH (NOLOCK) WHERE PID.Pickslipno = @c_sourcekey )
    BEGIN
      SET @c_condition1 = ' WHERE PID.Pickslipno = @c_sourcekey '  
    END

   IF ISNULL(@c_condition1,'') = ''
   BEGIN
      GOTO QUIT_SP
   END

   SET @c_SQLGroup = N' GROUP BY oh.loadkey,pid.pickslipno,l.pickzone '
   SET @c_SQLOrdBy = N' Order BY oh.loadkey,pid.pickslipno,l.pickzone '

    SET @c_SQL = @c_SQLinsert + CHAR(13) + @c_SQLSelect + CHAR(13) + @c_condition1 + CHAR(13) + @c_SQLGroup + CHAR(13) + @c_SQLOrdBy

  PRINT @c_SQL
   SET @c_ExecArguments = N'@c_sourcekey           NVARCHAR(20)'                          
                         
   EXEC sp_ExecuteSql     @c_SQL     
                        , @c_ExecArguments    
                        , @c_sourcekey   

  
   SELECT   *
   FROM #TMP_TLISTRPTIKEARDT

   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END
   
       QUIT_SP:
       
END -- procedure

GO