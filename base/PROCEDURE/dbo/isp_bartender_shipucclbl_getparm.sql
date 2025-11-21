SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/                   
/* Copyright: IDS                                                             */                   
/* Purpose: isp_Bartender_SHIPUCCLBL_GetParm                                  */                   
/*                                                                            */                   
/* Modifications log:                                                         */                   
/*                                                                            */                   
/* Date       Rev  Author     Purposes                                        */                   
/* 2018-09-18 1.0  CSCHONG    WMS-5850-5854                                   */    
/* 2018-09-20 1.1  CHEEMUN    INC0396805 - Get Parm03 Value                   */   
/* 2019-04-11 1.2  SPChin     INC0648102 - Cater Print From Exceed            */       
/* 2019-05-27 1.3  WLChooi    WMS-9075 - Can use LabelNo as input param (WL01)*/                    
/******************************************************************************/                  
                    
CREATE PROC [dbo].[isp_Bartender_SHIPUCCLBL_GetParm]                        
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
      @c_ReceiptKey        NVARCHAR(10),                      
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
      @c_SQLOrdBy        NVARCHAR(150)  
        
  DECLARE @d_Trace_StartTime   DATETIME,     
           @d_Trace_EndTime    DATETIME,    
           @c_Trace_ModuleName NVARCHAR(20),     
           @d_Trace_Step1      DATETIME,     
           @c_Trace_Step1      NVARCHAR(20),    
           @c_UserName         NVARCHAR(20),  
           @c_ExecStatements   NVARCHAR(4000),      
           @c_ExecArguments    NVARCHAR(4000)                                
    
   SET @d_Trace_StartTime = GETDATE()    
   SET @c_Trace_ModuleName = ''    
          
    -- SET RowNo = 0               
    SET @c_SQL = ''     
    SET @c_SQLJOIN = ''          
    SET @c_condition1 = ''  
    SET @c_condition2= ''  
    SET @c_SQLOrdBy = ''  
    SET @c_SQLGroup = ''  
    SET @c_ExecStatements = ''  
    SET @c_ExecArguments = ''  
    
    IF ISNULL(RTRIM(@parm03),'') = ''  --INC0648102
    BEGIN
       SET @c_SQLJOIN = 'SELECT DISTINCT PARM1= PD.Pickslipno,PARM2=PD.Cartonno,PARM3= PD.Cartonno ,PARM4= '''',PARM5='''',PARM6='''',PARM7='''', '+  
       'PARM8='''',PARM9='''',PARM10='''',Key1=''Pickslipno'',Key2=''Cartonno'',Key3='''',' +  
       ' Key4='''','+  
       ' Key5= '''' '  +    
       ' FROM PACKHEADER PH WITH (NOLOCK) ' +  
       ' JOIN PACKDETAIL PD WITH (NOLOCK) ON PD.PickSlipNo = PH.PickSlipNo'+    
       ' WHERE PH.Pickslipno = @Parm01 ' +  
       ' AND (PD.CartonNo = CONVERT(INT,@Parm02) OR PD.LabelNo = @Parm02) ' --WL01
        --AND PD.CartonNo <= CONVERT(INT,@Parm03)  '    
    END    
    ELSE
    BEGIN
       SET @c_SQLJOIN = 'SELECT DISTINCT PARM1= PD.Pickslipno,PARM2=PD.Cartonno,PARM3= PD.Cartonno ,PARM4= '''',PARM5='''',PARM6='''',PARM7='''', '+  
        'PARM8='''',PARM9='''',PARM10='''',Key1=''Pickslipno'',Key2=''Cartonno'',Key3='''',' +  
       ' Key4='''','+  
       ' Key5= '''' '  +    
       ' FROM PACKHEADER PH WITH (NOLOCK) ' +  
       ' JOIN PACKDETAIL PD WITH (NOLOCK) ON PD.PickSlipNo = PH.PickSlipNo'+    
       ' WHERE PH.Pickslipno = @Parm01 ' +  
       ' AND PD.CartonNo >= CONVERT(INT,@Parm02) ' + --AND PD.CartonNo <= CONVERT(INT,@Parm03)  '  
       ' AND PD.CartonNo <= CONVERT(INT,@Parm03) ' --INC0648102   
    END
  
        
      SET @c_SQL = @c_SQLJOIN   
       
      --PRINT @c_SQL  
       
    --EXEC sp_executesql @c_SQL      
      
   SET @c_ExecArguments = N'   @parm01           NVARCHAR(80)'      
                          + ', @parm02           NVARCHAR(80) '      
                          + ', @parm03           NVARCHAR(80)'               
                           
   EXEC sp_ExecuteSql     @c_SQL       
                        , @c_ExecArguments      
                        , @parm01      
                        , @parm02     
                        , @parm03  
              
   EXIT_SP:      
    
      SET @d_Trace_EndTime = GETDATE()    
      SET @c_UserName = SUSER_SNAME()    
                                   
   END -- procedure     


GO