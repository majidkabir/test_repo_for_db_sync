SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/                     
/* Copyright: LFL                                                             */                     
/* Purpose: isp_Bartender_SHIPUCCLBLVIP_GetParm                               */                     
/*                                                                            */                     
/* Modifications log:                                                         */                     
/*                                                                            */                     
/* Date       Rev  Author     Purposes                                        */     
/* 2020-09-11 1.0  WLChooi    Created (WMS-15133)                             */                
/******************************************************************************/                    
                      
CREATE PROC [dbo].[isp_Bartender_SHIPUCCLBLVIP_GetParm]                          
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
      @c_ExternOrderKey  NVARCHAR(50),          
      @c_Deliverydate    DATETIME,                  
      @n_intFlag         INT,         
      @n_CntRec          INT,        
      @c_SQL             NVARCHAR(4000),            
      @c_SQLSORT         NVARCHAR(4000),            
      @c_SQLJOIN         NVARCHAR(4000),  
      @c_SQLJOIN1        NVARCHAR(4000),    
      @c_condition1      NVARCHAR(150) ,    
      @c_condition2      NVARCHAR(150),    
      @c_SQLGroup        NVARCHAR(4000),    
      @c_SQLOrdBy        NVARCHAR(150)    
          
  DECLARE  @d_Trace_StartTime   DATETIME,       
           @d_Trace_EndTime    DATETIME,      
           @c_Trace_ModuleName NVARCHAR(20),       
           @d_Trace_Step1      DATETIME,       
           @c_Trace_Step1      NVARCHAR(20),      
           @c_UserName         NVARCHAR(20),    
           @c_ExecStatements   NVARCHAR(4000),        
           @c_ExecArguments    NVARCHAR(4000),  
           @c_Storerkey        NVARCHAR(15),                             
           @c_Key03            NVARCHAR(50) = '',       
           @c_Facility         NVARCHAR(5)  = '',
           @c_Type             NVARCHAR(50) = '',
           @c_DocType          NVARCHAR(50) = ''
  
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
   
   SELECT @c_Storerkey = Storerkey  
   FROM PACKHEADER (NOLOCK)  
   WHERE Pickslipno = @parm01  

   SELECT @c_ExternOrderKey = MAX(ORD.ExternOrderkey)
        , @c_Facility       = MAX(ORD.Facility) 
        , @c_Type           = MAX(ORD.[Type])
        , @c_DocType        = MAX(ORD.DocType)  
   FROM ORDERS ORD (NOLOCK)  
   JOIN PACKHEADER PH (NOLOCK) ON ORD.ORDERKEY = PH.ORDERKEY  
   WHERE PH.Pickslipno = @parm01  
   
   IF ISNULL(@c_ExternOrderKey,'') = ''  
   BEGIN  
      SELECT @c_ExternOrderKey = MAX(ORD.ExternOrderkey)
           , @c_Facility       = MAX(ORD.Facility) 
           , @c_Type           = MAX(ORD.[Type])
           , @c_DocType        = MAX(ORD.DocType)  
      FROM PACKHEADER PH (NOLOCK)  
      JOIN LOADPLANDETAIL LPD (NOLOCK) ON LPD.LOADKEY = PH.LOADKEY  
      JOIN ORDERS ORD (NOLOCK) ON ORD.ORDERKEY = LPD.ORDERKEY  
      WHERE PH.Pickslipno = @parm01  
   END  
   
   IF ISNULL(@c_Type,'') = 'VIP' AND ISNULL(@c_DocType,'') = 'E'
   BEGIN
      SET @c_SQLJOIN = ' SELECT DISTINCT PARM1 = PD.Pickslipno, PARM2 = PD.Cartonno, PARM3 = PD.Cartonno, PARM4= '''', PARM5='''', PARM6='''', PARM7='''', '+    
                       ' PARM8='''', PARM9='''', PARM10='''', Key1=''Pickslipno'', Key2=''Cartonno'', Key3='''', ' +    
                       ' Key4='''', ' +    
                       ' Key5= '''' ' +
                       ' FROM PACKHEADER PH WITH (NOLOCK) ' +    
                       ' JOIN PACKDETAIL PD WITH (NOLOCK) ON PD.PickSlipNo = PH.PickSlipNo'+      
                       ' WHERE PH.Pickslipno = @Parm01 ' +    
                       ' AND PD.CartonNo BETWEEN CONVERT(INT,@Parm02) AND CONVERT(INT,@Parm03) '  
                       
      SET @c_SQL = @c_SQL + @c_SQLJOIN
 
     
      SET @c_ExecArguments = N'  @parm01            NVARCHAR(80)'        
                             +', @parm02            NVARCHAR(80)'        
                             +', @parm03            NVARCHAR(80)'      
           
      EXEC sp_ExecuteSql     @c_SQL         
                           , @c_ExecArguments        
                           , @parm01        
                           , @parm02       
                           , @parm03     
   END
   ELSE
   BEGIN
   	GOTO EXIT_SP
   END
                        
EXIT_SP:        
   
   SET @d_Trace_EndTime = GETDATE()      
   SET @c_UserName = SUSER_SNAME()      
                                  
END -- procedure       

GO