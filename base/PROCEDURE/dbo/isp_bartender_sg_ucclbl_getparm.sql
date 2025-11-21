SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/                     
/* Copyright: LFL                                                             */                     
/* Purpose: isp_Bartender_SG_UCCLBL_GetParm                                   */                     
/*                                                                            */                     
/* Modifications log:                                                         */                     
/*                                                                            */                     
/* Date       Rev  Author     Purposes                                        */   
/* 2022-05-26 1.0  Mingle     Created (WMS-19656)                             */       
/* 2022-05-26 1.0  Mingle     DevOps Combine Script                           */  
/******************************************************************************/                    
CREATE PROC [dbo].[isp_Bartender_SG_UCCLBL_GetParm]                          
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
                                  
   DECLARE @c_SQL             NVARCHAR(4000),          
           @c_SQLJOIN         NVARCHAR(4000),   
           @c_ExecArguments   NVARCHAR(4000),  
           @c_GetOrderkey     NVARCHAR(10),  
           @c_DocType         NVARCHAR(50),  
           @c_Key3            NVARCHAR(50),  
           @c_CheckConso      NVARCHAR(10),  
     @d_Trace_StartTime   DATETIME,       
           @d_Trace_EndTime    DATETIME,      
           @c_Trace_ModuleName NVARCHAR(20),  
     @c_GetParm01        NVARCHAR(30),    
           @c_GetParm02        NVARCHAR(30),    
           @c_GetParm03        NVARCHAR(30),  
     @n_TTLCtn           INT,  
     @c_UserName         NVARCHAR(20),  
     @c_OrderGroup      NVARCHAR(50)  
                 
   SET @c_SQL = ''     
   SET @c_SQLJOIN = ''  
   SET @c_ExecArguments = ''  
   SET @d_Trace_StartTime = GETDATE()      
   SET @c_Trace_ModuleName = ''      
            
   -- SET RowNo = 0                 
  
   --Discrete    
   SELECT TOP 1 @c_GetOrderkey = ORDERS.Orderkey  
              , @c_DocType     = ORDERS.DocType  
     , @c_OrderGroup  = ORDERS.OrderGroup  
   FROM PACKHEADER (NOLOCK)    
   JOIN ORDERS (NOLOCK) ON ORDERS.ORDERKEY = PACKHEADER.ORDERKEY    
   WHERE PACKHEADER.Pickslipno = @parm01    
    
   IF ISNULL(@c_GetOrderkey,'') = ''    
   BEGIN    
      --Conso    
      SELECT TOP 1 @c_GetOrderkey = ORDERS.Orderkey    
                 , @c_DocType     = ORDERS.DocType  
     , @c_OrderGroup  = ORDERS.OrderGroup  
      FROM PACKHEADER (NOLOCK)    
      JOIN LOADPLANDETAIL (NOLOCK) ON PACKHEADER.LOADKEY = LOADPLANDETAIL.LOADKEY    
      JOIN ORDERS (NOLOCK) ON ORDERS.ORDERKEY = LOADPLANDETAIL.ORDERKEY    
      WHERE PACKHEADER.Pickslipno = @parm01    
    
      IF ISNULL(@c_GetOrderkey,'') <> ''    
         SET @c_CheckConso = 'Y'    
      ELSE    
         GOTO EXIT_SP    
   END    
  
   IF EXISTS (SELECT 1 FROM ORDERS WITH (NOLOCK)    
              WHERE ORDERS.Orderkey = @parm01)    
   BEGIN    
      SELECT @c_GetParm01 = MIN(PH.Pickslipno)     
      FROM PACKHEADER PH WITH (NOLOCK)    
      WHERE PH.Orderkey = @parm01    
   --SET @c_GetParm02 = '1'    
     --SET @c_Getparm03 = '9999'         
      SET @c_GetParm02 = CASE WHEN @parm02 = '' THEN '1' ELSE @parm02 END        
      SET @c_Getparm03 = CASE WHEN @parm03 = '' THEN '9999' ELSE @parm03 END                 
   END                      
   ELSE    
   BEGIN    
      SET @c_GetParm01 = @parm01    
      --SET @c_GetParm02 = @c_parm02    
      --SET @c_Getparm03 = @c_parm03      
      SET @c_GetParm02 = CASE WHEN @parm02 = '' THEN '1' ELSE @parm02 END        
      SET @c_Getparm03 = CASE WHEN @parm03 = '' THEN '9999' ELSE @parm03 END     
   END     
        
   SET @n_TTLCtn = 0    
   SELECT @n_TTLCtn = MAX(PDET.Cartonno)    
   FROM PACKDETAIL PDET WITH (NOLOCK)    
   WHERE PDET.Pickslipno = @c_GetParm01   
  
   IF @c_OrderGroup = 'aCommerce'  
   BEGIN  
  
   SET @c_Key3 = CASE WHEN @c_DocType = 'E' THEN 'IDENTITY_LBL' ELSE 'CARTONLBL' END  
        
   SET @c_SQLJOIN = ' SELECT DISTINCT PARM1 = PD.Pickslipno, PARM2 = PD.labelNo, PARM3 = '''' , PARM4 = '''', PARM5 = '''', PARM6 = '''', PARM7 = '''', ' + CHAR(13) +  
                    '                 PARM8 = '''', PARM9 = '''', PARM10 = '''', ' + CHAR(13) +  
                    '                 Key1 = ''Pickslipno'', Key2 = ''LabelNo'', Key3 = @c_Key3, Key4 = '''', Key5 = '''' ' + CHAR(13) +    
                    ' FROM PACKHEADER PH WITH (NOLOCK) ' + CHAR(13) +  
                    ' JOIN PACKDETAIL PD WITH (NOLOCK) ON PD.PickSlipNo = PH.PickSlipNo ' + CHAR(13) +  
                    ' WHERE PH.Pickslipno = @Parm01 '  + CHAR(13) +   
                    ' AND PD.CartonNo >= CONVERT(INT,@Parm02) AND PD.CartonNo <= CONVERT(INT,@Parm03) '  
   
   SET @c_SQL = @c_SQLJOIN  
     
   END  
   ELSE --ADIDAS TEMPORARY LABEL  
   BEGIN  
    SELECT DISTINCT PARM1=PDET.Pickslipno, PARM2=PDET.LabelNo,PARM3='',PARM4='',    
        PARM5='',PARM6='',PARM7='',    
        PARM8='',PARM9='',PARM10='',Key1='Pickslipno',Key2='LabelNo', Key3=ISNULL(O.ShipperKey,''),Key4='',Key5=''            
    FROM   PACKHEADER PH (NOLOCK)     
    JOIN PACKDETAIL PDET (NOLOCK) ON PDET.Pickslipno = PH.Pickslipno  
    JOIN ORDERS O WITH (NOLOCK) ON o.OrderKey=ph.OrderKey                          
    WHERE PDET.Pickslipno = @c_GetParm01 AND PDET.CartonNo >= CONVERT(INT,@c_GetParm02) AND PDET.CartonNo <= CONVERT(INT,@c_GetParm03)  
  
   END  
         
   SET @c_ExecArguments =  N'  @parm01           NVARCHAR(80)'        
                          + ', @parm02           NVARCHAR(80)'        
                          + ', @parm03           NVARCHAR(80)'      
                          + ', @parm04           NVARCHAR(80)'      
                          + ', @parm05           NVARCHAR(80)'    
                          + ', @c_Key3           NVARCHAR(80)'                  
                             
   EXEC sp_ExecuteSql     @c_SQL         
                        , @c_ExecArguments        
                        , @parm01        
                        , @parm02       
                        , @parm03    
                        , @parm04   
                        , @parm05    
                        , @c_Key3  
  
EXIT_SP:  
     
   SET @d_Trace_EndTime = GETDATE()      
   SET @c_UserName = SUSER_SNAME()  
  
END -- procedure   

GO