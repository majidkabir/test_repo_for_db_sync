SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/                 
/* Copyright: IDS                                                             */                 
/* Purpose: isp_Bartender_Shiplabel_GetParm                                   */                 
/*                                                                            */                 
/* Modifications log:                                                         */                 
/*                                                                            */                 
/* Date       Rev  Author     Purposes                                        */                 
/* 2016-11-11 1.0  CSCHONG    Created                                         */  
/* 2017-01-24 1.1  TLTING01   SET ANSI NULLS Option                           */  
/* 2017-05-30 1.2  CSCHONG    WMS-1932- Add new parameter (CS01)              */ 
/* 2017-09-11 1.3  CSCHONG    Enhance Dynamic SQL (CS02)                      */    
/* 2018-08-02 1.4  CSCHONG    WMS-5828&WMS5004-add new field (CS03)           */  
/* 2019-03-14 1.5  CSCHONG    WMS-8043 remove space for key05 (CS04)          */                     
/******************************************************************************/                
CREATE PROC [dbo].[isp_Bartender_SHIPLBLB2B_GetParm]                      
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
      @c_printUCClabel   NVARCHAR(5),            --CS03
      @c_getParm07       NVARCHAR(30)            --CS03
      
      
    
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
           @c_ExecStatements   NVARCHAR(4000),    --CS02 
           @c_ExecArguments    NVARCHAR(4000)     --CS02     
  
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
    SET @c_printUCClabel = 'N'            --CS03
    SET @c_getParm07     = ''             --CS03

    --CS03 Start
    IF EXISTS (SELECT 1 FROM PACKHEADER PH WITH (NOLOCK)
               WHERE PH.pickslipno = @parm01)
               
   BEGIN
     SET @c_printUCClabel = 'Y'
   END
   ELSE
   BEGIN

      IF @parm02 <> '' AND EXISTS (SELECT 1 FROM ORDERS WITH (NOLOCK)
                                   WHERE Orderkey = @parm02)
      BEGIN
         IF ISNULL(@parm01,'') <> ''
         BEGIN
            SELECT @c_getParm07 = ISNULL(OH.ECOM_SINGLE_Flag,'')
            FROM ORDERS OH WITH (NOLOCK)
            WHERE OH.Orderkey = @parm02
         END
         ELSE
         BEGIN
            SELECT TOP 1 @parm01 = OH.loadkey
            FROM ORDERS OH WITH (NOLOCK)
            WHERE OH.Orderkey = @parm02  
         END
      END
   END   
             
    --CS03 END


IF @c_printUCClabel='N'   --CS03 Start
BEGIN

  IF ISNULL(@parm05,'') = '' AND  ISNULL(@parm06,'') = ''   --CS01
  BEGIN
    IF ISNULL(@parm03,'') <>'' 
    BEGIN
    SET @c_SQLJOIN = 'SELECT PARM1= @parm01,PARM2=P.OrderKey,PARM3= @parm03 ,PARM4= CASE WHEN @c_getParm07 = ''S'' THEN ''0'' ELSE @parm04 END,' +
                     'PARM5='''',PARM6='''',PARM7=@c_getParm07, '+
                     'PARM8='''',PARM9='''',PARM10='''',Key1=''LoadKey'',Key2=''OrderKey'',Key3=''SF'',Key4=''YTO'','+
                     ' Key5= @parm03 '  +  
                     ' FROM   PICKDETAIL P (NOLOCK)     JOIN LOC l (NOLOCK) ON l.Loc = P.Loc '+  
                     ' JOIN LoadPlanDetail lpd (NOLOCK) ON lpd.OrderKey = P.OrderKey '+
                     ' JOIN Orders Ord (NOLOCK) ON Ord.loadkey=lpd.loadkey and Ord.orderkey=lpd.orderkey   '+
                     ' WHERE lpd.LoadKey =  @parm01  '
    END
    ELSE
    BEGIN
      SET @c_SQLJOIN = 'SELECT PARM1= @parm01,PARM2=P.OrderKey,PARM3= @parm03 ,PARM4= CASE WHEN @c_getParm07 = ''S'' THEN ''0'' ELSE @parm04 END,' +
                       'PARM5='''',PARM6='''',PARM7=@c_getParm07, '+
                       'PARM8='''',PARM9='''',PARM10='''',Key1=''LoadKey'',Key2=''OrderKey'',Key3=''SF'',Key4=''YTO'','+
                       ' Key5=LTRIM(RTRIM(Ord.Shipperkey)) ' + --Ord.Shipperkey '  +     --CS04
                       ' FROM   PICKDETAIL P (NOLOCK)     JOIN LOC l (NOLOCK) ON l.Loc = P.Loc '+  
                       ' JOIN LoadPlanDetail lpd (NOLOCK) ON lpd.OrderKey = P.OrderKey '+
                       ' JOIN Orders Ord (NOLOCK) ON Ord.loadkey=lpd.loadkey and Ord.orderkey=lpd.orderkey   '+
                       ' WHERE lpd.LoadKey =  @parm01 '
    END  
  END
  ELSE
  BEGIN
    SET @c_SQLJOIN = 'SELECT PARM1= @parm01,PARM2=P.OrderKey,PARM3= @parm03 ,PARM4= CASE WHEN @c_getParm07 = ''S'' THEN ''0'' ELSE @parm04 END,' +
                     'PARM5=@parm05,PARM6=@parm06,PARM7=@c_getParm07, '+
                     ' PARM8='''',PARM9='''',PARM10='''',Key1=''LoadKey'',Key2=''OrderKey'',Key3=''SF'',Key4=''YTO'','+
                     ' Key5= @parm03 '  +  
                     ' FROM PACKHEADER PH WITH (NOLOCK) ' +
                     ' JOIN PACKDETAIL PAD WITH (NOLOCK) ON PAD.Pickslipno = PH.Pickslipno'  +
                     ' JOIN PICKDETAIL P (NOLOCK) ON P.Pickslipno = PH.Pickslipno  '  +
                     ' JOIN LOC l (NOLOCK) ON l.Loc = P.Loc '+  
                     ' JOIN LoadPlanDetail lpd (NOLOCK) ON lpd.OrderKey = P.OrderKey '+
                     ' JOIN Orders Ord (NOLOCK) ON Ord.loadkey=lpd.loadkey and Ord.orderkey=lpd.orderkey   '+
                     ' WHERE lpd.LoadKey =  @parm01  '
  END   
    
       IF ISNULL(@parm02,'')  <> ''
       BEGIN       
          SET @c_condition1 = ' AND LPD.OrderKey =  @parm02  '
       END
       
       IF ISNULL(@parm03,'')  <> ''
       BEGIN       
          SET @c_condition2 = ' AND Ord.ShipperKey =  @parm03  '
       END
       
       
       
       IF (ISNULL(@parm04,'0')='0' OR @parm04 = '' OR  @parm04 = '8' )
       BEGIN 
         SET @c_SQLGroup = ' GROUP BY P.OrderKey,Ord.shipperkey '
         SET @c_SQLOrdBy = ' ORDER BY P.OrderKey'
       END  
       ELSE IF ISNULL(@parm04,'0') = '1' 
       BEGIN 
         
         SET @c_SQLGroup = ' GROUP BY P.OrderKey,Ord.shipperkey ' +
                           ' HAVING SUM(P.Qty) = 1 '
         SET @c_SQLOrdBy = ' ORDER BY MAX(l.LogicalLocation), MAX(P.Loc), P.OrderKey   '                  
           
       END
       ELSE
       BEGIN
         SET @c_SQLGroup = ' GROUP BY P.OrderKey,Ord.shipperkey ' +
                           ' HAVING SUM(P.Qty) >1 '
         SET @c_SQLOrdBy = ' ORDER BY MAX(P.notes),P.OrderKey ,MAX(P.Loc) '   
         
       END  
       SET @c_SQL = @c_SQLJOIN + @c_condition1 + @c_condition2 + @c_SQLGroup + @c_SQLOrdBy

END
ELSE
BEGIN

      SET @c_SQL = N'SELECT DISTINCT PARM1=OH.Loadkey, PARM2=PH.Orderkey,PARM3=OH.Shipperkey,PARM4=''0'' '
               +',PARM5=PD.CartonNo,PARM6=PD.CartonNo,PARM7=ISNULL(OH.ECOM_SINGLE_Flag,'''') ,PARM8='''',PARM9='''',PARM10='''' '
               +',Key1=''LoadKey'',Key2=''OrderKey'',Key3=''SF'',Key4=''YTO'' '
               + ',Key5= CASE WHEN ISNULL(OH.Shipperkey,'''') <> '''' THEN LTRIM(RTRIM(OH.Shipperkey)) ELSE ''NO'' END '--OH.Shipperkey '--CS04
               + ' FROM PACKHEADER PH WITH (NOLOCK) '
               + ' JOIN PACKDETAIL PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickslipNo) '
               + ' JOIN ORDERS     OH WITH (NOLOCK) ON (PH.Orderkey = OH.Orderkey) '
               +'  WHERE PH.Pickslipno = @Parm01 AND PD.CartonNo >= CONVERT(INT,@Parm02) AND PD.CartonNo <= CONVERT(INT,@Parm03) '
               + ' UNION ' + CHAR(13)
               + ' SELECT DISTINCT PARM1=OH.Loadkey, PARM2= CASE WHEN ISNULL(PH.orderkey,'''') <> '''' THEN PH.Orderkey ELSE '''' END'
               + ' ,PARM3=OH.Shipperkey,PARM4=''0'' '
               + ' ,PARM5=PD.CartonNo,PARM6=PD.CartonNo,PARM7=ISNULL(OH.ECOM_SINGLE_Flag,'''') ,PARM8='''',PARM9='''',PARM10='''' '
               + ' ,Key1=''LoadKey'',Key2=''OrderKey'',Key3=''SF'',Key4=''YTO'' '
               + ' ,Key5= CASE WHEN ISNULL(OH.Shipperkey,'''') <> '''' THEN LTRIM(RTRIM(OH.Shipperkey)) ELSE ''NO'' END '--OH.Shipperkey '--CS04
               + ' FROM PACKHEADER PH WITH (NOLOCK) '
               + ' JOIN PACKDETAIL PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickslipNo) '
               + ' JOIN ORDERS     OH WITH (NOLOCK) ON (PH.loadkey = OH.loadkey) '
               +'  WHERE PH.Pickslipno = @Parm01 AND PD.CartonNo >= CONVERT(INT,@Parm02) AND PD.CartonNo <= CONVERT(INT,@Parm03) '
               + ' AND ISNULL(PH.orderkey,'''') = '''' '
               + ' Order by OH.Loadkey,PH.Orderkey,PD.CartonNo'
END  --CS01 End      
       
    
      
       --PRINT @c_SQL
      
    --EXEC sp_executesql @c_SQL    
    
     --CS06 start
   SET @c_ExecArguments = N'   @parm01           NVARCHAR(80)'    
                          + ', @parm02           NVARCHAR(80) '    
                          + ', @parm03           NVARCHAR(80)'   
                          + ', @parm04           NVARCHAR(80) '    
                          + ', @parm05           NVARCHAR(80)'  
                          + ', @parm06           NVARCHAR(80)'  
                          + ', @c_getParm07      NVARCHAR(30) '         --Cs03
                         
                         
   EXEC sp_ExecuteSql     @c_SQL     
                        , @c_ExecArguments    
                        , @parm01    
                        , @parm02   
                        , @parm03
                        , @parm04
                        , @parm05  
                        , @parm06
                        , @c_getParm07           --CS03
            
   EXIT_SP:    
  
      SET @d_Trace_EndTime = GETDATE()  
      SET @c_UserName = SUSER_SNAME()  
     
                                  
   END -- procedure   



GO