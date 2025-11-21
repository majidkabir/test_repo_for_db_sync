SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
 
/************************************************************************/  
/* Store Procedure:  isp_UCC_Carton_Label_41                            */  
/* Creation Date: 7-Mar-2016                                            */  
/* Copyright: IDS                                                       */  
/* Written by: CSCHONG                                                  */  
/*                                                                      */  
/* Purpose:  To print Ucc Carton Label 40                               */  
/*                                                                      */  
/* Input Parameters: Parm01,Parm02,Parm03,Parm04,Parm05                 */  
/*                                                                      */  
/* Output Parameters:                                                   */  
/*                                                                      */  
/* Usage:                                                               */  
/*                                                                      */  
/* Called By:  r_dw_ucc_carton_label_41                                 */  
/*                                                                      */  
/* PVCS Version: 1.1                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author   Ver  Purposes                                  */  
/* 22-FEB-2018  CSCHONG  1.3  WMS-3953-Print by bartender (CS01)        */  
/* 03-MAY-2018  CSCHONG  1.4  Add printer id parameter (CS02)           */  
/* 05-NOV-2018  CSCHONG  1.5  Avoid many to many join (CS03)            */  
/************************************************************************/  
  
CREATE PROC [dbo].[isp_UCC_Carton_Label_41] (  
         @c_Parm01      NVARCHAR(20)  
      ,  @c_Parm02      NVARCHAR(20)  
      ,  @c_Parm03      NVARCHAR(20)  
      ,  @c_Parm04      NVARCHAR(20)  
      ,  @c_Parm05      NVARCHAR(250) = ''  
      ,  @c_printer     NVARCHAR(20) = ''  
)  
AS  
BEGIN  
  
   SET NOCOUNT ON  
   SET ANSI_DEFAULTS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
  
  DECLARE  @c_GetParm01      NVARCHAR(20)  
        ,  @c_GetParm02      NVARCHAR(20)  
        ,  @c_GetParm03      NVARCHAR(10)  
        ,  @c_GetParm04      NVARCHAR(10)  
        ,  @c_GetParm05      NVARCHAR(250)  
        ,  @c_storerkey      NVARCHAR(20)  
        ,  @c_Pickslipno     NVARCHAR(20)  
        ,  @c_labelnostart   NVARCHAR(20)  
        ,  @c_labelnoEnd     NVARCHAR(20)  
        ,  @c_CartonNoStart  NVARCHAR(10)  
        ,  @c_CartonNoEnd    NVARCHAR(250)  
        ,  @c_WaveKey        NVARCHAR(20)  
        ,  @c_RptType        NVARCHAR(10)  
        ,  @c_ByPickslip      NVARCHAR(1)  
     
     DECLARE  @c_ExecInsert          NVARCHAR(4000),      
              @c_ExecArguments       NVARCHAR(4000),      
              @c_ExecSelect          NVARCHAR(4000),     
              @c_ExecStatementsAll   NVARCHAR(MAX),      
              @c_FilterScripts       NVARCHAR(1000)  
       
    /*CS01 start*/               
 DECLARE @c_Getprinter     NVARCHAR(10),  
         @c_UserId         NVARCHAR(20),  
         @c_GetDatawindow  NVARCHAR(40),  
         @c_ReportID       NVARCHAR(10),  
         @n_noofParm       INT,  
         @b_success        int,  
         @n_err            int,  
         @c_errmsg         NVARCHAR(255),  
         @c_PrintbyBT      NVARCHAR(1),  
         @c_col01          NVARCHAR(60),    
         @c_col02          NVARCHAR(60),   
         @c_col03          NVARCHAR(60),   
         @c_col04          NVARCHAR(60)   
 /*CS01 End*/                 
  
   SET @c_GetParm01     = ''  
   SET @c_GetParm02     = ''  
   SET @c_GetParm03     = ''  
   SET @c_GetParm04     = ''  
   SET @c_GetParm05     = ''  
   SET @c_storerkey     = ''       
   SET @c_Pickslipno    = ''      
   SET @c_labelnostart  = ''   
   SET @c_labelnoEnd    = ''     
   SET @c_CartonNoStart = ''   
   SET @c_CartonNoEnd   = ''   
   SET @c_WaveKey = ''  
   SET @c_RptType = '0'  
   SET @c_ByPickslip  = 'N'  
   SET @c_UserId= SUSER_NAME()    --CS01  
   SET @c_PrintbyBT   = 'N'       --CS01  
     
     
   /*CS01 Start*/--CS02 Start  
   IF ISNULL(@c_printer,'') <> ''  
   BEGIN  
    SET @c_Getprinter = @c_printer  
   END  
   ELSE  
   BEGIN   
  SELECT @c_Getprinter = defaultprinter  
  FROM RDT.RDTUser AS r WITH (NOLOCK)  
  WHERE r.UserName = @c_UserId  
     
  IF ISNULL(@c_Getprinter,'') = ''  
  BEGIN  
     SET @c_Getprinter = 'PDF'  
  END  
   END  
   /*CS01 End*/ --CS02 End  
  
   CREATE TABLE #TMP_GETCOLUMN (  
          col01     NVARCHAR(20) NULL,  
          col02     NVARCHAR(20) NULL,  
          col03     NVARCHAR(20) NULL,  
          col04     NVARCHAR(20) NULL,  
          RptType   NVARCHAR(10) NULL)  
  
  
   IF Exists (Select 1 FROM Storer (NOLOCK)  
               WHERE Storerkey = @c_Parm01)  
    BEGIN  
     SET @c_storerkey = @c_Parm01   
    END  
    ELSE IF Exists (Select 1 FROM Packdetail (NOLOCK)  
               WHERE Pickslipno = @c_Parm01)  
    BEGIN  
     SET @c_Pickslipno = @c_Parm01  
     --SET @c_ByPickslip = 'Y'  
    END  
    ELSE IF Exists (Select 1 FROM wave (NOLOCK)  
               WHERE wavekey = @c_Parm01)  
   BEGIN  
     SET @c_WaveKey = @c_Parm01  
   END  
  
  IF Exists (Select 1 FROM Packdetail (NOLOCK)  
               WHERE Pickslipno = @c_Parm02)  
  BEGIN  
      SET @c_Pickslipno    = @c_Parm02  
      SET @c_CartonNoStart = @c_Parm03  
      SET @c_CartonNoEnd    =@c_Parm04  
      SET @c_ByPickslip = 'Y'    
  END  
  ELSE  
  BEGIN  
    SET @c_CartonNoStart = @c_Parm02  
    SET @c_CartonNoEnd   = @c_Parm03  
    SET @c_labelnostart  = @c_Parm04  
   -- SET @c_labelnoEnd    = @c_Parm05   
  END  
  
  
  IF ISNULL(@c_storerkey,'') = '' AND ISNULL(@c_Pickslipno,'') <> ''  
  BEGIN  
    SELECT @c_storerkey = Storerkey  
    FROM PACKHEADER WITH (NOLOCK)   
    WHERE Pickslipno = @c_Pickslipno  
  END  
  
  SELECT TOP 1 @c_RptType = ISNULL(ORD.UpdateSource,'0')  
  FROM PICKDETAIL PID WITH (NOLOCK)  
  JOIN ORDERS ORD WITH (NOLOCK) ON ORD.Orderkey = PID.Orderkey  
  WHERE PID.Pickslipno = @c_Pickslipno  
    
    
     /*CS01 Start*/  
       
     IF @c_RptType = 'R01'  
     BEGIN  
       SET @c_PrintbyBT = 'Y'  
     END   
       
     /*CS01 End*/  
   
 SET @c_GetParm01  = @c_storerkey  
  
  IF ISNULL(@c_labelnostart,'') = ''  
  BEGIN  
    SET @c_GetParm02 = @c_Pickslipno  
    SET @c_ByPickslip = 'Y'   
  END  
  ELSE  
   BEGIN  
    SET @c_GetParm02 = @c_labelnostart  
  END  
  
   SET @c_GetParm03 = @c_CartonNoStart  
   SET @c_GetParm04 = @c_CartonNoEnd  
     
     
 --  SELECT @c_GetParm02 AS '@c_GetParm02',@c_GetParm03 AS '@c_GetParm02',@c_GetParm04 AS '@c_GetParm03'  
  
  --SELECT @c_GetParm02 as '@c_GetParm02',@c_ByPickslip as '@c_ByPickslip'  
     
    IF @c_ByPickslip = 'Y'  
    BEGIN  
      
   INSERT INTO #TMP_GETCOLUMN (col01,col02,col03,col04,Rpttype)  
   SELECT DISTINCT PAH.storerkey,PAH.Pickslipno,cartonno,cartonno,@c_RptType  
   FROM PACKHEADER PAH WITH (NOLOCK)  
   JOIN PACKDETAIL PADET WITH (NOLOCK) ON PAH.Pickslipno = PADET.Pickslipno    
   JOIN PICKDETAIL PIDET WITH (NOLOCK) ON PIDET.CaseId = PADET.Labelno AND PIDET.SKU = PADET.SKU    --CS03  
   WHERE PAH.Pickslipno = @c_GetParm02  
   AND PADET.CartonNo BETWEEN CONVERT(INT,@c_GetParm03) AND CONVERT(INT,@c_GetParm04)   
  
    END  
    ELSE  
    BEGIN  
   INSERT INTO #TMP_GETCOLUMN (col01,col02,col03,col04,Rpttype)  
   SELECT DISTINCT PAH.storerkey,PAH.Pickslipno,cartonno,cartonno,@c_RptType  
   FROM PACKHEADER PAH WITH (NOLOCK)  
   JOIN PACKDETAIL PADET WITH (NOLOCK) ON PAH.Pickslipno = PADET.Pickslipno    
   JOIN PICKDETAIL PIDET WITH (NOLOCK) ON PIDET.CaseId = PADET.Labelno  AND PIDET.SKU = PADET.SKU    --CS03  
   WHERE PADET.labelno = @c_GetParm02  
   AND PADET.CartonNo BETWEEN CONVERT(INT,@c_GetParm03) AND CONVERT(INT,@c_GetParm04)   
  
    END  
 IF @c_PrintbyBT='N'    --CS01 start  
   BEGIN     
  
     SELECT col01 ,col02, col03, col04,Rpttype  
     FROM #TMP_GETCOLUMN  
   END  
   ELSE  
   BEGIN  
      
    SELECT  @c_col01 = col01  
           ,@c_col02 = col02  
           ,@c_col03 = col03  
           ,@c_col04 = col04  
    FROM #TMP_GETCOLUMN  
      
      
    EXEC isp_BT_GenBartenderCommand          
          @cPrinterID = @c_Getprinter  
         ,@c_LabelType = 'RETAILLBL'  
         ,@c_userid = @c_UserId  
         ,@c_Parm01 = @c_col01  
         ,@c_Parm02 = @c_col02  
         ,@c_Parm03 = @c_col03  
         ,@c_Parm04 = @c_col04  
         ,@c_Parm05 = ''  
         ,@c_Parm06 = ''  
         ,@c_Parm07 = ''  
         ,@c_Parm08 = ''  
         ,@c_Parm09 = ''  
         ,@c_Parm10 = ''  
         ,@c_Storerkey = @c_Storerkey  
         ,@c_NoCopy = 1  
         ,@c_Returnresult = 'N'   
         ,@n_err = @n_Err OUTPUT  
         ,@c_errmsg = @c_ErrMsg OUTPUT    
        
  
   IF @n_err <> 0  
   BEGIN  
          GOTO QUIT_SP     
   END  
     
       
   SELECT col01 ,col02, col03, col04,Rpttype  
       FROM #TMP_GETCOLUMN  
   END   
      
END  
  
QUIT_SP:  


GO