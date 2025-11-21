SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/                   
/* Copyright: LFL                                                             */                   
/* Purpose: isp_Bartender_SHIPUCCLB3_GetParm                                  */   
/*          Support Storerkey + LabelNo OR Pickslipno + CartonFrom + CartonTo */  
/*          OR Pickslipno + LabelNo OR Pickslipno + Carton                    */                
/*                                                                            */                   
/* Modifications log:                                                         */                   
/*                                                                            */                   
/* Date       Rev  Author     Purposes                                        */                   
/* 2021-03-26 1.0  WLChooi    Created (WMS-16672)                             */  
/* 2021-11-10 1.1  CSCHONG    Devops scripts combine                          */ 
/* 2021-11-10 1.2  CSCHONG    WMS-18254 new printing parameter (CS01)         */                  
/******************************************************************************/                        
CREATE PROC [dbo].[isp_Bartender_SHIPUCCLB3_GetParm]                        
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
      @c_SQLOrdBy        NVARCHAR(150)  
        
   DECLARE @d_Trace_StartTime  DATETIME,     
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

    --(Storerkey + LabelNo)
    IF EXISTS (SELECT 1 FROM PACKDETAIL (NOLOCK) WHERE Storerkey = @parm01 AND LabelNo = @parm02)
    BEGIN
       SET @c_SQLJOIN = ' SELECT DISTINCT PARM1= PD.Pickslipno,PARM2=PD.Cartonno,PARM3=PD.Cartonno ,PARM4= '''',PARM5='''',PARM6='''',PARM7='''', '+  
                        ' PARM8='''',PARM9='''',PARM10='''',Key1=''Pickslipno'',Key2=''Cartonno'',Key3='''',' +  
                        ' Key4='''','+  
                        ' Key5= '''' '  +    
                        ' FROM PACKHEADER PH WITH (NOLOCK) ' +  
                        ' JOIN PACKDETAIL PD WITH (NOLOCK) ON PD.PickSlipNo = PH.PickSlipNo'+    
                        ' WHERE PH.Storerkey = @Parm01 ' +  
                        ' AND PD.LabelNo = @Parm02 '
    END
    --(Pickslipno + LabelNo)
    ELSE IF EXISTS (SELECT 1 FROM PACKDETAIL (NOLOCK) WHERE PickSlipNo = @parm01 AND LabelNo = @parm02)
    BEGIN
       SET @c_SQLJOIN = ' SELECT DISTINCT PARM1= PD.Pickslipno,PARM2=PD.Cartonno,PARM3=PD.Cartonno ,PARM4= '''',PARM5='''',PARM6='''',PARM7='''', '+  
                        ' PARM8='''',PARM9='''',PARM10='''',Key1=''Pickslipno'',Key2=''Cartonno'',Key3='''',' +  
                        ' Key4='''','+  
                        ' Key5= '''' '  +    
                        ' FROM PACKHEADER PH WITH (NOLOCK) ' +  
                        ' JOIN PACKDETAIL PD WITH (NOLOCK) ON PD.PickSlipNo = PH.PickSlipNo'+    
                        ' WHERE PH.Pickslipno = @Parm01 ' +  
                        ' AND PD.LabelNo = @Parm02 '
    END 
    --(Pickslipno + CartonNo)
    ELSE IF EXISTS (SELECT 1 FROM PACKDETAIL (NOLOCK) WHERE PickSlipNo = @parm01 AND CartonNo = @parm02) AND ISNULL(@parm03,'') = ''
    BEGIN
       SET @c_SQLJOIN = ' SELECT DISTINCT PARM1= PD.Pickslipno,PARM2=PD.Cartonno,PARM3=PD.Cartonno ,PARM4= '''',PARM5='''',PARM6='''',PARM7='''', '+  
                        ' PARM8='''',PARM9='''',PARM10='''',Key1=''Pickslipno'',Key2=''Cartonno'',Key3='''',' +  
                        ' Key4='''','+  
                        ' Key5= '''' '  +    
                        ' FROM PACKHEADER PH WITH (NOLOCK) ' +  
                        ' JOIN PACKDETAIL PD WITH (NOLOCK) ON PD.PickSlipNo = PH.PickSlipNo'+    
                        ' WHERE PH.Pickslipno = @Parm01 ' +  
                        ' AND PD.CartonNo = @Parm02 '
    END  
     ELSE  IF EXISTS (SELECT 1 FROM ORDERS (NOLOCK) WHERE orderkey = @parm01) AND ISNUMERIC(@parm02) = 1 AND ISNUMERIC(@parm03) = 1    /*CS01 START*/
    --(orderkey + ttlctn + noofcopy)
    BEGIN
       SET @c_SQLJOIN = ' SELECT DISTINCT PARM1= OH.Orderkey,PARM2=@Parm02,PARM3=@Parm03 ,PARM4= '''',PARM5='''',PARM6='''',PARM7='''', '+  
                        ' PARM8='''',PARM9='''',PARM10='''',Key1=''orderkey'',Key2=''ttlctn'',Key3='''',' +  
                        ' Key4='''','+  
                        ' Key5= '''' '  +    
                        ' FROM ORDERS OH WITH (NOLOCK) ' +  
                --        ' JOIN PACKDETAIL PD WITH (NOLOCK) ON PD.PickSlipNo = PH.PickSlipNo'+    
                        ' WHERE OH.orderkey = @Parm01 '  
               --         ' AND PD.CartonNo >= CONVERT(INT,@Parm02) ' +
               --        ' AND PD.CartonNo <= CONVERT(INT,@Parm03) '
    END
   /*CS01 END*/
    ELSE
    --(Pickslipno + CartonFrom + CartonTo)
    BEGIN
       SET @c_SQLJOIN = ' SELECT DISTINCT PARM1= PD.Pickslipno,PARM2=PD.Cartonno,PARM3= PD.Cartonno ,PARM4= '''',PARM5='''',PARM6='''',PARM7='''', '+  
                        ' PARM8='''',PARM9='''',PARM10='''',Key1=''Pickslipno'',Key2=''Cartonno'',Key3='''',' +  
                        ' Key4='''','+  
                        ' Key5= '''' '  +    
                        ' FROM PACKHEADER PH WITH (NOLOCK) ' +  
                        ' JOIN PACKDETAIL PD WITH (NOLOCK) ON PD.PickSlipNo = PH.PickSlipNo'+    
                        ' WHERE PH.Pickslipno = @Parm01 ' +  
                        ' AND PD.CartonNo >= CONVERT(INT,@Parm02) ' +
                        ' AND PD.CartonNo <= CONVERT(INT,@Parm03) '
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