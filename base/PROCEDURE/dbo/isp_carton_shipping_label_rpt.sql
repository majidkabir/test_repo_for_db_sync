SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure:  isp_Carton_shipping_Label_rpt                      */
/* Creation Date: 12-Jan-2019                                           */
/* Copyright: IDS                                                       */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose: WMS-7507-CarterSZ_Viewreport_Shipping_Label                 */
/*                                                                      */
/* Input Parameters: Parm01,Parm02,Parm03,Parm04,Parm05                 */
/*                                                                      */
/* Output Parameters:                                                   */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Called By:  r_dw_Carton_shipping_Label_rpt                           */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver  Purposes                                  */
/* 26-AUG-2019  CSCHONG  1.1  Performance tunning (CS01)                */
/* 04-Oct-2021  WinSern  1.2  INC1626948 Performance tunning (ws01)     */
/************************************************************************/

CREATE PROC [dbo].[isp_Carton_shipping_Label_rpt] (
         @c_Storerkey    NVARCHAR(20),
         @c_wavekey      NVARCHAR(20),
		 @c_loadkeyFrom  NVARCHAR(20),
		 @c_loadkeyTo    NVARCHAR(20),
		 @c_CaseIDFrom   NVARCHAR(20),
		 @c_CaseIDTo     NVARCHAR(20)
)
AS
BEGIN

   SET NOCOUNT ON
   SET ANSI_DEFAULTS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF


  DECLARE  @c_labelno        NVARCHAR(20)
        ,  @c_orderkey       NVARCHAR(20)
        ,  @c_RptType        NVARCHAR(10)
        ,  @c_loadkey        NVARCHAR(20)   
        ,  @n_ContainerQty   INT
        ,  @n_getrowid       INT
        ,  @n_CntRec         INT
        ,  @c_ContainerType  NVARCHAR(20)  
		,  @c_GetStorerkey   NVARCHAR(20) 
        ,  @c_OHUDF09        NVARCHAR(50)  
        ,  @c_SQL            NVARCHAR(4000)
        ,  @c_SQLSORT        NVARCHAR(4000) 
        ,  @c_SQLJOIN        NVARCHAR(4000) 
       	,  @c_ExecStatements NVARCHAR(4000)
        ,  @c_ExecArguments  NVARCHAR(4000)
		,  @c_condition1     NVARCHAR(500)
		,  @c_condition2     NVARCHAR(500)
		,  @c_condition3     NVARCHAR(500)
		,  @c_SQLGroup       NVARCHAR(4000)
        ,  @c_SQLOrdBy       NVARCHAR(500)
		,  @c_SQLInsert      NVARCHAR(4000)
				  		 
 DECLARE @c_Getprinter     NVARCHAR(10),
         @c_UserId         NVARCHAR(20),
         @c_GetDatawindow  NVARCHAR(40),
         @c_ReportID       NVARCHAR(10),
         @n_noofParm       INT,
         @b_success        int,
         @n_err            int,
         @c_errmsg         NVARCHAR(255)
                  			   
   SET @c_labelno       = ''  
   SET @c_RptType       = '0'
  
   SET @c_Getprinter = ''
   SET @c_ReportID=''
   SET @c_UserId= SUSER_NAME()
   SET @n_noofParm = 1
   SET @c_GetDatawindow  = ''
   SET @c_SQL = ''

   DECLARE @n_StartTCnt       INT    --ws01  
   SET @n_StartTCnt = @@TRANCOUNT    --ws01      
    
   WHILE @@TRANCOUNT >  0			 --ws01  
   COMMIT TRAN						 --ws01 
   
   SELECT @c_Getprinter = defaultprinter
   FROM RDT.RDTUser AS r WITH (NOLOCK)
   WHERE r.UserName = @c_UserId
   
   IF ISNULL(@c_Getprinter,'') = ''
   BEGIN
   	SET @c_Getprinter = 'PDF'
   END


   CREATE TABLE #TMP_GETCOLUMN (
          [RowID]    [INT] IDENTITY(1,1) NOT NULL,
          col01     NVARCHAR(20) NULL,
          col02     NVARCHAR(20) NULL,
          col03     NVARCHAR(20) NULL,
          col04     NVARCHAR(20) NULL,
          col05     NVARCHAR(30) NULL,
          Col06     NVARCHAR(50) NULL,
          col07     NVARCHAR(50) NULL)

   CREATE TABLE #TMP_PLabel (
          [ID]    [INT] IDENTITY(1,1) NOT NULL, 
          Storerkey    NVARCHAR(20) NULL,
          Orderkey     NVARCHAR(20) NULL,
          Loadkey      NVARCHAR(20) NULL,
          wavekey      NVARCHAR(20) NULL,
          Labelno      NVARCHAR(20) NULL)         
  

     SET @c_SQLInsert = N'INSERT INTO #TMP_PLabel (Storerkey,Orderkey,Loadkey,wavekey,Labelno) '

	 SET @c_SQLJOIN = N'SELECT DISTINCT OH.Storerkey,OH.Orderkey,OH.Loadkey,OH.Userdefine09,PID.CaseID'
	                + ' FROM WAVEDETAIL WD WITH (NOLOCK) ' + CHAR(13)                            --CS01
					+ ' JOIN ORDERS OH WITH (NOLOCK) ON OH.Orderkey = WD.Orderkey '  + CHAR(13)      --CS01
					+ ' LEFT JOIN PICKDETAIL PID WITH (NOLOCK) ON PID.Storerkey = OH.Storerkey AND PID.Orderkey = OH.Orderkey  '
     
	 SET @c_condition1 = ' WHERE OH.Storerkey = @c_Storerkey AND WD.Wavekey = @c_wavekey ' --AND OH.Userdefine09 = @c_wavekey'

	 SET @c_condition2 = ''
	 SET @c_condition3 = ''

	 IF ISNULL(@c_loadkeyFrom,'') <> '' AND ISNULL(@c_loadkeyTo,'') <> ''
	 BEGIN
	   SET @c_condition2 = ' AND OH.Loadkey >= @c_loadkeyFrom AND OH.Loadkey <= @c_loadkeyTo ' 
	 END

	 IF ISNULL(@c_CaseIDFrom,'') <> '' AND ISNULL(@c_CaseIDTo,'') <> ''
	 BEGIN
	   SET @c_condition3 = ' AND PID.Caseid > = @c_CaseIDFrom AND PID.Caseid < = @c_CaseIDTo'
	 END


	 SET @c_SQLOrdBy = ' Order by OH.Userdefine09,PID.Caseid'
 
	 SET @c_SQL = @c_SQLInsert + CHAR(13) + @c_SQLJOIN + CHAR(13) + @c_condition1 + CHAR(13) + @c_condition2 + CHAR(13) + @c_condition3

 

 SET @c_ExecArguments = N'     @c_Storerkey      NVARCHAR(20)'    
                          + ', @c_wavekey        NVARCHAR(20) '    
                          + ', @c_loadkeyFrom    NVARCHAR(20)'   
                          + ', @c_loadkeyTo      NVARCHAR(20) '    
                          + ', @c_CaseIDFrom     NVARCHAR(20)'  
                          + ', @c_CaseIDTo       NVARCHAR(20)'  
                         
                         
   EXEC sp_ExecuteSql     @c_SQL     
                        , @c_ExecArguments    
                        , @c_Storerkey    
                        , @c_wavekey   
                        , @c_loadkeyFrom
                        , @c_loadkeyTo
                        , @c_CaseIDFrom
                        , @c_CaseIDTo
 
 DECLARE CUR_StartRecLoop CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
 
   SELECT DISTINCT Storerkey,Orderkey,Loadkey,wavekey,Labelno
   FROM #TMP_PLabel  t 
   ORDER BY Orderkey,Labelno

  OPEN CUR_StartRecLoop

  FETCH NEXT FROM CUR_StartRecLoop INTO  @c_GetStorerkey
                                       , @c_orderkey
									   , @c_loadkey
									   , @c_ohudf09
                                       , @c_labelno          
                                                          
   WHILE @@FETCH_STATUS <> -1
   BEGIN

   SET @n_ContainerQty = 0
   SET @c_ContainerType = ''
   SET @c_GetDatawindow = ''
   SET @c_RptType = ''

    SELECT   @n_ContainerQty       = ContainerQty
            ,@c_ContainerType      = ContainerType
      FROM  Orders WITH (NOLOCK) 
      WHERE OrderKey = @c_orderkey

      IF ISNULL(@c_ContainerType,'' )  <> '' 
      BEGIN
         SELECT @c_RptType = UDF01 
         FROM CodeLKup WITH (NOLOCK) 
         WHERE ListName IN (  'CZLABEL', 'CAWMINTLBL' ) 
         AND Short = @c_ContainerType
      END   
         IF ISNULL(@c_RptType,'' )  = '' 
         BEGIN
            GOTO Quit_SP
         END
         
         SELECT @c_GetDatawindow = DataWindow       
         FROM rdt.rdtReport WITH (NOLOCK)     
         WHERE StorerKey = @c_GetStorerkey    
         AND   ReportType = @c_RptType

   IF NOT EXISTS (SELECT 1 FROM #TMP_GETCOLUMN where col02 = @c_orderkey and col05=@c_labelno)        
   BEGIN
     INSERT INTO #TMP_GETCOLUMN (col01,col02,col03,col04,col05,col06,col07)
     VALUES(@c_GetStorerkey,@c_orderkey,@c_loadkey,@c_ohudf09,@c_labelno,@c_RptType,@c_GetDatawindow)       
     
      IF ISNULL(@c_GetDatawindow,'') <> ''
      BEGIN      	   	        	
         EXEC isp_PrintToRDTSpooler 
                @c_ReportType  = @c_RptType, 
                @c_Storerkey   = @c_Storerkey,
                @b_success	    = @b_success OUTPUT,
                @n_err		    = @n_err OUTPUT,
                @c_errmsg	    = @c_errmsg OUTPUT,
                @n_Noofparam   = @n_noofParm,
                @c_Param01     = @c_labelno,
                @c_Param02     = '',
                @c_Param03     = '',
                @c_Param04     = '',
                @c_Param05     = '',
                @c_Param06     = '',
                @c_Param07     = '',
                @c_Param08     = '',
                @c_Param09     = '',
                @c_Param10     = '',
                @n_Noofcopy    = 1,
                @c_UserName    = @c_UserId,
                @c_Facility    = '',
                @c_PrinterID   = @c_Getprinter,
                @c_Datawindow  = @c_GetDatawindow,
                @c_IsPaperPrinter = 'Y'
      
         IF @b_success <> 1 
         BEGIN
            --SELECT @n_continue = 3
            GOTO QUIT_SP   
         END
      END
   END

   FETCH NEXT FROM CUR_StartRecLoop INTO @c_GetStorerkey
                                       , @c_orderkey
                                       , @c_loadkey
                                       , @c_ohudf09
                                       , @c_labelno    

   END
   CLOSE CUR_StartRecLoop
   DEALLOCATE CUR_StartRecLoop

  SELECT col01 ,col02, col03, col04,col05,col06,col07
  FROM #TMP_GETCOLUMN
 
  
   DROP TABLE #TMP_PLabel
   DROP TABLE #TMP_GETCOLUMN

   QUIT_SP:

   WHILE @n_StartTCnt > @@TRANCOUNT   --ws01  
   BEGIN TRAN						  --ws01

END

GO