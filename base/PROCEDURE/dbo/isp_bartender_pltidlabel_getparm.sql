SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/                 
/* Copyright: IDS                                                             */                 
/* Purpose: isp_Bartender_PLTIDLABEL_GetParm                                  */                 
/*                                                                            */                 
/* Modifications log:                                                         */                 
/*                                                                            */                 
/* Date       Rev  Author     Purposes                                        */                 
/* 2019-02-22 1.0  CSCHONG    Created(WMS-8048)                               */                            
/******************************************************************************/                
                  
CREATE PROC [dbo].[isp_Bartender_PLTIDLABEL_GetParm]                      
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
           @c_getUCCno         NVARCHAR(20),
           @c_getUdef09        NVARCHAR(30),
           @c_ExecStatements   NVARCHAR(4000),    
           @c_ExecArguments    NVARCHAR(4000),
           @n_CtnSKU           INT ,
           @c_SKUBUSR1         NVARCHAR(30) 
  
   SET @d_Trace_StartTime = GETDATE()  
   SET @c_Trace_ModuleName = ''  
   SET @n_CtnSKU = 1
        
    -- SET RowNo = 0             
    SET @c_SQL = ''    
    SET @c_SQLJOIN = ''        
    SET @c_condition1 = ''
    SET @c_condition2= ''
    SET @c_SQLOrdBy = ''
    SET @c_SQLGroup = ''
    SET @c_ExecStatements = ''
    SET @c_ExecArguments = ''
    SET @c_SKUBUSR1 = ''

   --SELECT @n_CtnSKU = COUNT(SKU)
   --FROM PackDetail PD WITH (NOLOCK)
   --WHERE PD.PickSlipNo = @parm01

   --IF @n_CtnSKU = 1
   --BEGIN

   --SELECT @c_SKUBUSR1 = S.busr1
   --FROM PackDetail PD WITH (NOLOCK)
   --JOIN SKU S WITH (NOLOCK) ON S.StorerKey=PD.StorerKey AND S.Sku = PD.SKU
   --WHERE PD.PickSlipNo = @parm01

   --END

   --IF @n_CtnSKU > 1 OR @c_SKUBUSR1 <> 'Y'
   --BEGIN

   -- GOTO EXIT_SP

   --END
 --   ELSE
   --BEGIN


    SET @c_SQLJOIN = 'SELECT DISTINCT PARM1= PD.PickSlipNo,PARM2= PD.Refno , ' +
                     ' PARM3= CASE WHEN S.BUSR1 = ''N'' THEN PD.SKU ELSE '''' END,PARM4= PD.labelno,PARM5='''',PARM6='''',PARM7='''', '+
                    'PARM8='''',PARM9='''',PARM10='''',Key1=''pickslipno'',Key2=''ID'',Key3='''',Key4='''','+
                    ' Key5= '''' '  +  
                    ' FROM   PACKDETAIL PD WITH (NOLOCK) '+  
                    ' JOIN SKU S WITH (NOLOCK) ON S.StorerKey=PD.StorerKey AND S.Sku = PD.SKU ' +
                    ' WHERE PD.PickSlipNo =  @parm01  '  +
                    ' AND PD.labelno = @parm02' +
                    ' GROUP BY PD.PickSlipNo,PD.Refno,CASE WHEN S.BUSR1 = ''N'' THEN PD.SKU ELSE '''' END,PD.labelno '
                    
                  
       
       SET @c_SQL = @c_SQLJOIN   
    

   SET @c_ExecArguments = N'   @parm01           NVARCHAR(80)'    
                          + ', @parm02           NVARCHAR(80) '    
                          + ', @parm03           NVARCHAR(80)'   
                          + ', @parm04           NVARCHAR(80) '    
                          + ', @parm05           NVARCHAR(80)'  
                          + ', @parm06           NVARCHAR(80)'  
                         
                         
   EXEC sp_ExecuteSql     @c_SQL     
                        , @c_ExecArguments    
                        , @parm01    
                        , @parm02   
                        , @parm03
                        , @parm04
                        , @parm05  
                        , @parm06

  --END     
  
  --select @c_SQL       
   EXIT_SP:    
  
      SET @d_Trace_EndTime = GETDATE()  
      SET @c_UserName = SUSER_SNAME()  
                                  
   END -- procedure   


GO