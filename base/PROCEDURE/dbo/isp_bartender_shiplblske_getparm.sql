SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/                   
/* Copyright: LFL                                                             */                   
/* Purpose: isp_Bartender_SHIPLBLSKE_GetParm                                  */   
/*          Support Pickslipno + CartonFrom + CartonTo                        */  
/*          OR Pickslipno + LabelNo OR Pickslipno + Carton                    */                
/*                                                                            */                   
/* Modifications log:                                                         */                   
/*                                                                            */                   
/* Date       Rev  Author     Purposes                                        */                   
/* 2021-08-04 1.0  WLChooi    Created (WMS-17538)                             */                    
/******************************************************************************/                        
CREATE PROC [dbo].[isp_Bartender_SHIPLBLSKE_GetParm]                        
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
           @c_ExecArguments    NVARCHAR(4000),
           @c_CheckConso       NVARCHAR(10) = 'N',
           @c_TableLinkage     NVARCHAR(1000) = '',
           @c_GetOrderkey      NVARCHAR(10) = ''                             
    
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

    --Discrete  
   SELECT TOP 1 @c_GetOrderkey = ORDERS.Orderkey
   FROM PACKHEADER (NOLOCK)  
   JOIN ORDERS (NOLOCK) ON ORDERS.ORDERKEY = PACKHEADER.ORDERKEY  
   WHERE PACKHEADER.Pickslipno = @parm01  
  
   IF ISNULL(@c_GetOrderkey,'') = ''  
   BEGIN  
      --Conso  
      SELECT TOP 1 @c_GetOrderkey = ORDERS.Orderkey
      FROM PACKHEADER (NOLOCK)  
      JOIN LOADPLANDETAIL (NOLOCK) ON PACKHEADER.LOADKEY = LOADPLANDETAIL.LOADKEY  
      JOIN ORDERS (NOLOCK) ON ORDERS.ORDERKEY = LOADPLANDETAIL.ORDERKEY  
      WHERE PACKHEADER.Pickslipno = @parm01  
  
      IF ISNULL(@c_GetOrderkey,'') <> ''  
         SET @c_CheckConso = 'Y'  
      ELSE  
         GOTO EXIT_SP  
   END  

   IF @c_CheckConso = 'Y'
   BEGIN
      SET @c_TableLinkage = 'JOIN LOADPLANDETAIL LPD (NOLOCK) ON LPD.Loadkey = PH.Loadkey ' + CHAR(13) + 
                            'JOIN ORDERS OH (NOLOCK) ON LPD.Orderkey = OH.Orderkey '
   END
   ELSE
   BEGIN
      SET @c_TableLinkage = 'JOIN ORDERS OH WITH (NOLOCK) ON (PH.Orderkey = OH.Orderkey) '
   END

    --(Pickslipno + LabelNo)
    IF EXISTS (SELECT 1 FROM PACKDETAIL (NOLOCK) WHERE PickSlipNo = @parm01 AND LabelNo = @parm02)
    BEGIN
       SET @c_SQLJOIN = ' SELECT DISTINCT PARM1 = OH.Loadkey, PARM2 = PH.Orderkey, PARM3 = OH.Shipperkey, PARM4 = ''0'', ' +
						      ' PARM5 = PD.CartonNo, PARM6 = PD.CartonNo, PARM7 = OH.ECOM_SINGLE_Flag, PARM8 = '''', PARM9 = '''', PARM10 = '''', ' +
						      ' Key1=''LoadKey'',Key2=''OrderKey'',Key3=''SF'',Key4=''YTO'',Key5=OH.Shipperkey ' +    
                        ' FROM PACKHEADER PH WITH (NOLOCK) ' +
                        ' JOIN PACKDETAIL PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickslipNo) ' +
                        @c_TableLinkage +
                        ' WHERE PH.Pickslipno = @Parm01 ' +
                        ' AND PD.LabelNo = @Parm02 '
    END 
    --(Pickslipno + CartonNo)
    ELSE IF EXISTS (SELECT 1 FROM PACKDETAIL (NOLOCK) WHERE PickSlipNo = @parm01 AND CartonNo = @parm02) AND ISNULL(@parm03,'') = ''
    BEGIN
       SET @c_SQLJOIN = ' SELECT DISTINCT PARM1 = OH.Loadkey, PARM2 = PH.Orderkey, PARM3 = OH.Shipperkey, PARM4 = ''0'', ' +
						      ' PARM5 = PD.CartonNo, PARM6 = PD.CartonNo, PARM7 = OH.ECOM_SINGLE_Flag, PARM8 = '''', PARM9 = '''', PARM10 = '''', ' +
						      ' Key1=''LoadKey'',Key2=''OrderKey'',Key3=''SF'',Key4=''YTO'',Key5=OH.Shipperkey ' +    
                        ' FROM PACKHEADER PH WITH (NOLOCK) ' +
                        ' JOIN PACKDETAIL PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickslipNo) ' +
                        @c_TableLinkage +
                        ' WHERE PH.Pickslipno = @Parm01 ' +
                        ' AND PD.CartonNo = @Parm02 '
    END  
    ELSE
    --(Pickslipno + CartonFrom + CartonTo)
    BEGIN
       SET @c_SQLJOIN = ' SELECT DISTINCT PARM1 = OH.Loadkey, PARM2 = PH.Orderkey, PARM3 = OH.Shipperkey, PARM4 = ''0'', ' +
						      ' PARM5 = PD.CartonNo, PARM6 = PD.CartonNo, PARM7 = OH.ECOM_SINGLE_Flag, PARM8 = '''', PARM9 = '''', PARM10 = '''', ' +
						      ' Key1=''LoadKey'',Key2=''OrderKey'',Key3=''SF'',Key4=''YTO'',Key5=OH.Shipperkey ' +    
                        ' FROM PACKHEADER PH WITH (NOLOCK) ' +
                        ' JOIN PACKDETAIL PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickslipNo) ' +
                        @c_TableLinkage +
                        ' WHERE PH.Pickslipno = @Parm01 ' +
                        ' AND PD.CartonNo >= CONVERT(INT,@Parm02) ' +
                        ' AND PD.CartonNo <= CONVERT(INT,@Parm03) '
    END

        
   SET @c_SQL = @c_SQLJOIN       
      
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