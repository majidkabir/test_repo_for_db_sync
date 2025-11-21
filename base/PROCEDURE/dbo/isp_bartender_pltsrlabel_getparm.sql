SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/                 
/* Copyright: IDS                                                             */                 
/* Purpose: isp_Bartender_PLTSRLABEL_GetParm                                  */                 
/*                                                                            */                 
/* Modifications log:                                                         */                 
/*                                                                            */                 
/* Date       Rev  Author     Purposes                                        */                 
/* 2019-01-09 1.0  CSCHONG    WMS-7545                                        */                            
/******************************************************************************/                
                  
CREATE PROC [dbo].[isp_Bartender_PLTSRLABEL_GetParm]                      
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
      @c_condition3      NVARCHAR(150),
      @c_SQLGroup        NVARCHAR(4000),
      @c_SQLOrdBy        NVARCHAR(150),
      @c_storerkey       NVARCHAR(20)
      
    
  DECLARE  @d_Trace_StartTime   DATETIME,   
           @d_Trace_EndTime    DATETIME,  
           @c_Trace_ModuleName NVARCHAR(20),   
           @d_Trace_Step1      DATETIME,   
           @c_Trace_Step1      NVARCHAR(20),  
           @c_UserName         NVARCHAR(20),
           @c_getUCCno         NVARCHAR(20),
           @c_getUdef09        NVARCHAR(30),
           @c_ExecStatements   NVARCHAR(4000),    
           @c_ExecArguments    NVARCHAR(4000)      
  
   SET @d_Trace_StartTime = GETDATE()  
   SET @c_Trace_ModuleName = ''  
        
    -- SET RowNo = 0             
    SET @c_SQL = ''    
    SET @c_SQLJOIN = ''        
    SET @c_condition1 = ''
    SET @c_condition2= ''
    SET @c_condition3= ''
    SET @c_SQLOrdBy = ''
    SET @c_SQLGroup = ''
    SET @c_ExecStatements = ''
    SET @c_ExecArguments = ''

   SELECT TOP 1 @c_storerkey = PLTDET.Storerkey
   FROM PALLETDETAIL PLTDET WITH (NOLOCK) 
   WHERE PLTDET.Palletkey =  RTRIM(@Parm01)

    SET @c_SQLJOIN = 'SELECT DISTINCT PARM1=PLTDET.PalletKey,PARM2=PD.SKU,PARM3='''',PARM4='''',PARM5='''',PARM6='''',PARM7='''', '+
                'PARM8='''',PARM9='''',PARM10='''',Key1=''Palletkey'',Key2='''',Key3='''',Key4='''','+
                ' Key5= '''' '  +  
                ' FROM PALLETDETAIL PLTDET WITH (NOLOCK) '+
                ' JOIN PackDetail PD WITH (NOLOCK) ON PD.LabelNo = PLTDET.CaseId AND PD.Storerkey = PLTDET.Storerkey'+  
                ' JOIN SerialNo SN WITH (NOLOCK) ON SN.PickSlipNo = PD.PickSlipNo AND SN.CartonNo = PD.CartonNo ' +
                '                                   AND  SN.StorerKey = PD.StorerKey' +
                ' WHERE PLTDET.Palletkey =  RTRIM(@Parm01)  '  +
                ' AND PLTDET.Storerkey = @c_storerkey ' +
                ' AND SN.ExternStatus <> ''CANC'' ' +
                ' ORDER BY PLTDET.PalletKey,PD.SKU'
   
       
       
       SET @c_SQL = @c_SQLJOIN 
      
      -- PRINT @c_SQL
      
    --EXEC sp_executesql @c_SQL    
    
   
   SET @c_ExecArguments = N'   @parm01           NVARCHAR(80)'    
                          + ', @c_storerkey      NVARCHAR(80) '   
                    
                         
                         
   EXEC sp_ExecuteSql     @c_SQL     
                        , @c_ExecArguments    
                        , @parm01    
                        , @c_storerkey
                           
   EXIT_SP:    
  
      SET @d_Trace_EndTime = GETDATE()  
      SET @c_UserName = SUSER_SNAME()  
                                  
   END -- procedure   


GO