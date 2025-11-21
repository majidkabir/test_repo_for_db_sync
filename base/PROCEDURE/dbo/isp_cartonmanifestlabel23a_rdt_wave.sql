SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/      
/* Store Procedure:  isp_CartonManifestLabel23a_rdt_wave                */      
/* Creation Date: 7-Mar-2016                                            */      
/* Copyright: IDS                                                       */      
/* Written by: CSCHONG                                                  */      
/*                                                                      */      
/* Purpose:  To print Ucc Carton Label 56                               */      
/*                                                                      */      
/* Input Parameters: Parm01,Parm02,Parm03,Parm04,Parm05                 */      
/*                                                                      */      
/* Output Parameters:                                                   */      
/*                                                                      */      
/* Usage:                                                               */      
/*                                                                      */      
/* Called By:  r_dw_CartonManifest_Label23a_rdt_wave                    */      
/*                                                                      */      
/* PVCS Version: 1.1                                                    */      
/*                                                                      */      
/* Version: 5.4                                                         */      
/*                                                                      */      
/* Data Modifications:                                                  */      
/*                                                                      */      
/* Updates:                                                             */      
/* Date         Author   Ver  Purposes                                  */      
/* 27 MAY 2022  KuanYee  1.0  Cater TCPSpooler Printing (KY01)          */ 
/* 06 JUL 2022  AikLiang 1.1  Performance Tune (AL01)                   */
/************************************************************************/      
      
CREATE PROC [dbo].[isp_CartonManifestLabel23a_rdt_wave] (      
         @c_wavekey NVARCHAR(10)       
)      
AS      
BEGIN      
      
   SET NOCOUNT ON      
   SET ANSI_DEFAULTS OFF      
   SET QUOTED_IDENTIFIER OFF      
   SET CONCAT_NULL_YIELDS_NULL OFF      
      
      
  DECLARE  @c_storerkey      NVARCHAR(20)      
        ,  @c_Pickslipno     NVARCHAR(20)      
        ,  @c_labelno        NVARCHAR(20)      
        ,  @c_RptType        NVARCHAR(10)      
        ,  @c_cartonno       NVARCHAR(10)      
        ,  @c_sku            NVARCHAR(20)      
        ,  @c_getlabelno     NVARCHAR(20)         
        ,  @n_rowid          INT      
        ,  @n_getrowid       INT      
        ,  @n_CntRec         INT      
        ,  @c_getOrdBuyerPO  NVARCHAR(20)         
        ,  @c_OrdLabelno     NVARCHAR(20)        
        ,  @c_logicalLoc     NVARCHAR(10)      
        ,  @c_getLoc         NVARCHAR(10)      
        ,  @c_GetLocAisle    NVARCHAR(10)      
        ,  @n_CntLocAisle    INT      
        ,  @n_getCntLocAisle INT      
             
   --CS01a start      
   DECLARE @c_Llabelno NVARCHAR(20)      
          ,@c_label_content NVARCHAR(4000)         
          ,@c_Lsku NVARCHAR(20)        
          ,@n_Lqty INT      
          ,@c_Getlblcontent NVARCHAR(4000)         
                
 --CS02 start      
 DECLARE @c_Getprinter     NVARCHAR(10),      
         @c_UserId         NVARCHAR(20),      
         @c_GetDatawindow  NVARCHAR(40),      
         @c_ReportID       NVARCHAR(10),      
         @n_noofParm       INT,      
         @b_success        int,      
         @n_err            int,      
         @c_errmsg         NVARCHAR(255)      
      
   
   DECLARE @n_StartTCnt       INT    --AL01    
   SET @n_StartTCnt = @@TRANCOUNT               --AL01        
      
   WHILE @@TRANCOUNT >  0      --AL01    
   COMMIT TRAN         --AL01          
      
      
   SET @c_storerkey     = ''           
   SET @c_Pickslipno    = ''          
   SET @c_labelno       = ''        
   SET @c_RptType       = '0'      
         
   --CS01a start      
   SET @c_Llabelno=''      
   SET @c_label_content=''      
   SET @c_Lsku=''      
   SET @n_Lqty=0      
         
   SET @c_Getprinter = ''      
   SET @c_ReportID='CtnMnfLbl'      
   SET @c_UserId= SUSER_NAME()      
   SET @n_noofParm = 4      
   SET @c_GetDatawindow  = 'r_dw_carton_manifest_label_23a_rdt'         
         
   SELECT @c_Getprinter = defaultprinter_paper  
   FROM RDT.RDTUser AS r WITH (NOLOCK)      
   WHERE r.UserName = @c_UserId      
         
   IF ISNULL(@c_Getprinter,'') = ''     
   BEGIN      
      SET @c_Getprinter = 'PDF'      
   END      
      
      
   CREATE TABLE #TMP_GETCOLUMN23a (      
          [RowID]    [INT] IDENTITY(1,1) NOT NULL,      
          col01     NVARCHAR(20) NULL,      
          col02     NVARCHAR(20) NULL,      
          col03     NVARCHAR(20) NULL,      
          col04     NVARCHAR(20) NULL)      
      
   CREATE TABLE #TMP_WAVE23aPICK (      
          [ID]    [INT] IDENTITY(1,1) NOT NULL,       
          Storerkey    NVARCHAR(20) NULL,      
          wavekey      NVARCHAR(20) NULL,      
          Pickslipno   NVARCHAR(20) NULL,      
          CartonNo     INT)      
                 
                
      
 INSERT INTO #TMP_WAVE23aPICK (Storerkey,wavekey,Pickslipno,CartonNo)      
  SELECT DISTINCT ORD.Storerkey,WVDET.WAVEKEY,PH.PICKSLIPNO,PD.cartonno                                
  FROM wavedetail WVDET WITH (NOLOCK)      
  JOIN ORDERS ORD WITH (NOLOCK) ON ORD.ORDERKEY = WVDET.ORDERKEY      
  JOIN PACKHEADER PH WITH (NOLOCK) ON PH.loadkey = ORD.loadkey      
  JOIN PACKDETAIL PD WITH (NOLOCK) ON PD.pickslipno = PH.pickslipno      
  WHERE WVDET.WaveKey = @c_wavekey      
  GROUP BY ORD.Storerkey,WVDET.WAVEKEY,PH.PICKSLIPNO      
 ,PD.Cartonno      
  ORDER BY PH.PICKSLIPNO,PD.cartonno      
       
 DECLARE CUR_StartRecLoop CURSOR LOCAL FAST_FORWARD READ_ONLY FOR       
       
   SELECT DISTINCT storerkey,Pickslipno,CartonNo      
   FROM #TMP_WAVE23aPICK       
   WHERE wavekey = @c_wavekey      
   ORDER BY storerkey,Pickslipno,CartonNo      
      
  OPEN CUR_StartRecLoop      
      
  FETCH NEXT FROM CUR_StartRecLoop INTO  @c_storerkey      
                                       , @c_Pickslipno      
                                       , @c_cartonno      
                                            
                                                                
      
   WHILE @@FETCH_STATUS <> -1      
   BEGIN      
      
   IF NOT EXISTS (SELECT 1 FROM #TMP_GETCOLUMN23a where col02 = @c_pickslipno and col03=@c_cartonno)              
   BEGIN      
     INSERT INTO #TMP_GETCOLUMN23a (col01,col02,col03,col04)      
     VALUES(@c_storerkey,@c_Pickslipno,@c_cartonno,@c_wavekey)             
           
      IF ISNULL(@c_GetDatawindow,'') <> ''      
         BEGIN                            
           EXEC isp_PrintToRDTSpooler       
                @c_ReportType  = @c_ReportID,       
                @c_Storerkey   = @c_Storerkey,      
                @b_success     = @b_success OUTPUT,      
                @n_err         = @n_err OUTPUT,      
                @c_errmsg      = @c_errmsg OUTPUT,      
                @n_Noofparam   = @n_noofParm,      
                @c_Param01     = @c_pickslipno,      
                @c_Param02     = @c_cartonno,      
                @c_Param03     = @c_cartonno,      
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
                @c_IsPaperPrinter = 'Y',      
                --@c_JobType     = 'QCOMMANDER'   --KY01     
                @c_JobType     = 'TCPSPOOLER'    
            
               IF @b_success <> 1       
               BEGIN      
                   --SELECT @n_continue = 3      
                  GOTO QUIT_SP         
               END      
         END       
             
   END      
      
   FETCH NEXT FROM CUR_StartRecLoop INTO @c_storerkey      
                                       , @c_Pickslipno      
                                       , @c_cartonno      
                 
      
   END      
   CLOSE CUR_StartRecLoop      
   DEALLOCATE CUR_StartRecLoop      
      
  SELECT col01 ,col02, col03, col04      
  FROM #TMP_GETCOLUMN23a      
      
        
END      
      
      
QUIT_SP:   
  
   WHILE @n_StartTCnt > @@TRANCOUNT   --AL01    
   BEGIN TRAN        --AL01 


GO