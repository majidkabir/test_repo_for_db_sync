SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/                 
/* Copyright: IDS                                                             */                 
/* Purpose: isp_Bartender_ikea_Shiplabel_GetParm                              */                 
/*                                                                            */                 
/* Modifications log:                                                         */                 
/*                                                                            */                 
/* Date       Rev  Author     Purposes                                        */                 
/* 2018-09-24 1.0  CSCHONG    Created(WMS-5940)                               */       
/* 2020-02-12 1.1  WLChooi    WMS-11177 - Cater for other Shipperkey (WL01)   */   
/* 2021-08-30 1.2  CSCHONG    WMS-17789 - cater for orders.m_fax2 (CS01)      */            
/******************************************************************************/                
                  
CREATE PROC [dbo].[isp_Bartender_ikea_Shiplabel_GetParm]                      
(  @parm01            NVARCHAR(250),              
   @parm02            NVARCHAR(250),              
   @parm03            NVARCHAR(250),              
   @parm04            NVARCHAR(250),              
   @parm05            NVARCHAR(250),              
   @parm06            NVARCHAR(250),              
   @parm07            NVARCHAR(250),              
   @parm08            NVARCHAR(250),              
   @parm09            NVARCHAR(250),              
   @parm10            NVARCHAR(250),        
   @b_debug           INT = 0                         
)                      
AS                      
BEGIN                      
   SET NOCOUNT ON                 
   SET ANSI_NULLS OFF                
   SET QUOTED_IDENTIFIER OFF                 
   SET CONCAT_NULL_YIELDS_NULL OFF                
                              
   DECLARE                  
      @c_ReceiptKey      NVARCHAR(10),                    
      @c_ExternOrderKey  NVARCHAR(10),              
      @c_Deliverydate    DATETIME,              
      @n_intFlag         INT,     
      @n_CntRec          INT,    
      @c_SQL             NVARCHAR(4000),        
      @c_SQLSORT         NVARCHAR(4000),        
      @c_SQLJOIN         NVARCHAR(4000),
      @c_condition1      NVARCHAR(150) ,
      @c_condition2      NVARCHAR(150),
      @c_SQLGroup        NVARCHAR(4000),
      @c_SQLOrdBy        NVARCHAR(150),
      @c_printbypickslip NVARCHAR(5),            
      @c_getParm07       NVARCHAR(30)            
      
      
    
  DECLARE @d_Trace_StartTime   DATETIME,   
           @d_Trace_EndTime    DATETIME,  
           @c_Trace_ModuleName NVARCHAR(20),   
           @d_Trace_Step1      DATETIME,   
           @c_Trace_Step1      NVARCHAR(20),  
           @c_UserName         NVARCHAR(20),
           @n_cntsku           INT,
           @c_mode             NVARCHAR(1),
           @c_sku              NVARCHAR(20),
           @c_getUCCno         NVARCHAR(20),
           @c_getUdef09        NVARCHAR(30),
           @c_ExecStatements   NVARCHAR(4000),    
           @c_ExecArguments    NVARCHAR(4000)       
  
   SET @d_Trace_StartTime = GETDATE()  
   SET @c_Trace_ModuleName = ''  
        
    -- SET RowNo = 0             
    SET @c_SQL = ''   
    SET @c_mode = '0'   
    SET @c_getUCCno = ''
    SET @c_getUdef09 = ''  
    SET @c_SQLJOIN = ''        
    SET @c_condition1 = ''
    SET @c_condition2= ''
    SET @c_SQLOrdBy = ''
    SET @c_SQLGroup = ''
    SET @c_ExecStatements = ''
    SET @c_ExecArguments = ''
    SET @c_printbypickslip = 'N'           
    SET @c_getParm07     = ''             

    --CS03 Start
    IF EXISTS (SELECT 1 FROM PACKHEADER PH WITH (NOLOCK)
               WHERE PH.pickslipno = @parm01 and ISNULL(PH.Pickslipno,'') <> '')
               
   BEGIN
     SET @c_printbypickslip = 'Y'
   END
   ELSE IF EXISTS (SELECT 1 FROM PACKHEADER PH WITH (NOLOCK)
               WHERE PH.orderkey = @parm01 and ISNULL(PH.Pickslipno,'') <> '')
   BEGIN
    SET @c_printbypickslip = 'N'

    IF ISNULL(@Parm02,'') = ''
    BEGIN
       SET @Parm02 = '1'
    END

    IF ISNULL(@Parm03,'') = ''
    BEGIN
       SET @Parm03 = '9999'
    END
  END

IF @c_printbypickslip='Y'   
BEGIN
    SET @c_SQL = N'SELECT DISTINCT PARM1=OH.Loadkey, PARM2=PH.Orderkey,PARM3=OH.Shipperkey,PARM4=''0'' '
                  +',PARM5=PD.CartonNo,PARM6=PD.CartonNo,PARM7=OH.ECOM_SINGLE_Flag ,PARM8='''',PARM9='''',PARM10='''' '
                  +',Key1=''LoadKey'',Key2=''OrderKey'',Key3=''SF''' --Key4=''YTO'' '                                   --CS01 
                  +',Key4=CASE WHEN ISNULL(OH.Shipperkey,'''') = ''SN'' AND ISNULL(OH.m_fax2,'''') <> '''' THEN ISNULL(OH.m_fax2,'''') ELSE ''NO'' END  '  --CS01
                  +',Key5=CASE WHEN ISNULL(OH.Shipperkey,'''') = '''' THEN ''NO'' ELSE ISNULL(OH.Shipperkey,'''') END  ' --WL01
                  + 'FROM PACKHEADER PH WITH (NOLOCK) '
                  + 'JOIN PACKDETAIL PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickslipNo) '
                  + 'JOIN ORDERS     OH WITH (NOLOCK) ON (PH.Orderkey = OH.Orderkey) '
                 +' WHERE PH.Pickslipno = @Parm01 AND PD.CartonNo >= CONVERT(INT,@Parm02) AND PD.CartonNo <= CONVERT(INT,@Parm03) '
END      
ELSE
BEGIN

SET @c_SQL = N'SELECT DISTINCT PARM1=OH.Loadkey, PARM2=PH.Orderkey,PARM3=OH.Shipperkey,PARM4=''0'' '
                  +',PARM5=PD.CartonNo,PARM6=PD.CartonNo,PARM7=OH.ECOM_SINGLE_Flag ,PARM8='''',PARM9='''',PARM10='''' '
                  +',Key1=''LoadKey'',Key2=''OrderKey'',Key3=''SF'' ' --Key4=''YTO'' '                                   --CS01 
                  +',Key4=CASE WHEN ISNULL(OH.Shipperkey,'''') = ''SN'' AND ISNULL(OH.m_fax2,'''') <> '''' THEN ISNULL(OH.m_fax2,'''') ELSE ''NO'' END  '  --CS01
                  +',Key5=CASE WHEN ISNULL(OH.Shipperkey,'''') = '''' THEN ''NO'' ELSE ISNULL(OH.Shipperkey,'''') END  ' --WL01
                  + 'FROM PACKHEADER PH WITH (NOLOCK) '
                  + 'JOIN PACKDETAIL PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickslipNo) '
                  + 'JOIN ORDERS     OH WITH (NOLOCK) ON (PH.Orderkey = OH.Orderkey) '
                 +' WHERE PH.Orderkey = @Parm01 AND PD.CartonNo >= CONVERT(INT,@Parm02) AND PD.CartonNo <= CONVERT(INT,@Parm03)'

END
       
    
      
       PRINT @c_SQL
      

   SET @c_ExecArguments = N'   @parm01           NVARCHAR(80)'    
                          + ', @parm02           NVARCHAR(80) '    
                          + ', @parm03           NVARCHAR(80)'   
                          + ', @parm04           NVARCHAR(80) '    
                          + ', @parm05           NVARCHAR(80)'  
                          + ', @parm06           NVARCHAR(80)'  
                          + ', @c_getParm07      NVARCHAR(30) '         
                         
                         
   EXEC sp_ExecuteSql     @c_SQL     
                        , @c_ExecArguments    
                        , @parm01    
                        , @parm02   
                        , @parm03
                        , @parm04
                        , @parm05  
                        , @parm06
                        , @c_getParm07           
            
   EXIT_SP:    
  
      SET @d_Trace_EndTime = GETDATE()  
      SET @c_UserName = SUSER_SNAME()  
     
                                  
   END   



GO