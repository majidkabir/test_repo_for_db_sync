SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/                     
/* Copyright: IDS                                                             */                     
/* Purpose: isp_Bartender_SHIPUCCLBLSKE_GetParm                               */                     
/*                                                                            */                     
/* Modifications log:                                                         */                     
/*                                                                            */                     
/* Date       Rev  Author     Purposes                                        */     
/* 2019-09-03 1.0  WLChooi    Created (WMS-10365)                             */    
/* 2020-09-01 1.1  WLChooi    WMS-14927 - Add Key05 (WL01)                    */                          
/******************************************************************************/                    
                      
CREATE PROC [dbo].[isp_Bartender_SHIPUCCLBLSKE_GetParm]                          
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
      @c_ExternOrderKey  NVARCHAR(50),          --WL02          
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
           @c_Facility         NVARCHAR(5) = '',   --WL01 
           @c_PrintNewLayout   NVARCHAR(10) = 'NONTJ'   --WL01
  
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
    SET @c_Key03 = 'NONSA'  
   
    SELECT @c_Storerkey = Storerkey  
    FROM PACKHEADER (NOLOCK)  
    WHERE Pickslipno = @parm01  
  
    SELECT @c_ExternOrderKey = MAX(ORD.ExternOrderkey)
         , @c_Facility = MAX(ORD.Facility)   --WL01  
    FROM ORDERS ORD (NOLOCK)  
    JOIN PACKHEADER PH (NOLOCK) ON ORD.ORDERKEY = PH.ORDERKEY  
    WHERE PH.Pickslipno = @parm01  
  
    IF ISNULL(@c_ExternOrderKey,'') = ''  
    BEGIN  
       SELECT @c_ExternOrderKey = MAX(ORD.ExternOrderkey)  
            , @c_Facility = MAX(ORD.Facility)   --WL01  
       FROM PACKHEADER PH (NOLOCK)  
       JOIN LOADPLANDETAIL LPD (NOLOCK) ON LPD.LOADKEY = PH.LOADKEY  
       JOIN ORDERS ORD (NOLOCK) ON ORD.ORDERKEY = LPD.ORDERKEY  
       WHERE PH.Pickslipno = @parm01  
    END  
  
    IF ISNULL(@c_ExternOrderKey,'') <> ''  
    BEGIN  
       IF LTRIM(RTRIM(ISNULL(@c_ExternOrderKey,''))) LIKE 'SA%'   
          SET @c_Key03 = 'SA'  
    END  

    --WL01 START
    SELECT @c_PrintNewLayout = CASE WHEN ISNULL(CL.Long,'') = '' THEN 'NONTJ' ELSE 'TJ' END
    FROM CODELKUP CL (NOLOCK)
    WHERE CL.LISTNAME = 'BTConfig'
    AND CL.Storerkey = @c_Storerkey
    AND CL.Long = 'TJ'
    AND CL.Code = @c_Facility
    --WL01 END

    IF ISNULL(RTRIM(@parm03),'') = ''    
    BEGIN  
       SET @c_SQLJOIN = 'SELECT DISTINCT PARM1= PD.Pickslipno,PARM2=PD.Cartonno,PARM3= PD.Cartonno ,PARM4= '''',PARM5='''',PARM6='''',PARM7='''', '+    
       'PARM8='''',PARM9='''',PARM10='''',Key1=''Pickslipno'',Key2=''Cartonno'',Key3=@c_Key03,' +    
       ' Key4=''1_NONBARCODE'','+    
       ' Key5= @c_PrintNewLayout '  +   --WL01
       ' FROM PACKHEADER PH WITH (NOLOCK) ' +    
       ' JOIN PACKDETAIL PD WITH (NOLOCK) ON PD.PickSlipNo = PH.PickSlipNo'+      
       ' WHERE PH.Pickslipno = @Parm01 ' +    
       ' AND (PD.CartonNo = CONVERT(INT,@Parm02) OR PD.LabelNo = @Parm02) '   
        --AND PD.CartonNo <= CONVERT(INT,@Parm03)  '      
    END      
    ELSE  
    BEGIN  
       SET @c_SQLJOIN = 'SELECT DISTINCT PARM1= PD.Pickslipno,PARM2=PD.Cartonno,PARM3= PD.Cartonno ,PARM4= '''',PARM5='''',PARM6='''',PARM7='''', '+    
        'PARM8='''',PARM9='''',PARM10='''',Key1=''Pickslipno'',Key2=''Cartonno'',Key3=@c_Key03,' +    
       ' Key4=''1_NONBARCODE'','+    
       ' Key5= @c_PrintNewLayout '  +   --WL01      
       ' FROM PACKHEADER PH WITH (NOLOCK) ' +    
       ' JOIN PACKDETAIL PD WITH (NOLOCK) ON PD.PickSlipNo = PH.PickSlipNo'+      
       ' WHERE PH.Pickslipno = @Parm01 ' +    
       ' AND PD.CartonNo >= CONVERT(INT,@Parm02) ' + --AND PD.CartonNo <= CONVERT(INT,@Parm03)  '    
       ' AND PD.CartonNo <= CONVERT(INT,@Parm03) '      
    END  
      
    SET @c_SQLJOIN1 = 'SELECT DISTINCT PARM1= PD.Pickslipno,PARM2=PD.Cartonno,PARM3= PD.Cartonno ,PARM4= '''',PARM5='''',PARM6='''',PARM7='''', '+    
                      ' PARM8='''',PARM9='''',PARM10=''BARCODE'',Key1=''Pickslipno'',Key2=''Cartonno'',Key3=@c_Key03,' +    
                      ' Key4=''2_BARCODE'','+    
                      ' Key5= '''' '  +      
                      ' FROM PACKHEADER PH WITH (NOLOCK) ' +    
                      ' JOIN PACKDETAIL PD WITH (NOLOCK) ON PD.PickSlipNo = PH.PickSlipNo'+      
                      ' WHERE PH.Pickslipno = @Parm01 ' +    
                      ' AND PD.CartonNo >= CONVERT(INT,@Parm02) ' + --AND PD.CartonNo <= CONVERT(INT,@Parm03)  '    
                      ' AND PD.CartonNo <= CONVERT(INT,@Parm03) ' +  
                      ' ORDER BY PD.CartonNo '    
  
   SET @c_SQL = @c_SQL + @c_SQLJOIN  + ' UNION ALL ' + @c_SQLJOIN1  
    
        
   SET @c_ExecArguments = N'  @parm01            NVARCHAR(80)'        
                          +', @parm02            NVARCHAR(80)'        
                          +', @parm03            NVARCHAR(80)'      
                          +', @c_Key03           NVARCHAR(80)'
                          +', @c_PrintNewLayout  NVARCHAR(80)'   --WL01               
                             
   EXEC sp_ExecuteSql     @c_SQL         
                        , @c_ExecArguments        
                        , @parm01        
                        , @parm02       
                        , @parm03    
                        , @c_Key03 
                        , @c_PrintNewLayout   --WL01    
   EXIT_SP:        
      
      SET @d_Trace_EndTime = GETDATE()      
      SET @c_UserName = SUSER_SNAME()      
                                     
   END -- procedure       


GO