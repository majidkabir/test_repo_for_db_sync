SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/                 
/* Copyright: LFL                                                             */                 
/* Purpose: isp_Bartender_CN_PVHLBL1_GetParm                                  */                 
/*                                                                            */                 
/* Modifications log:                                                         */                 
/*                                                                            */                 
/* Date       Rev  Author     Purposes                                        */                 
/* 2020-04-29 1.0  WLChooi    Created (WMS-13194)                             */    
/* 2021-02-23 1.1  CSCHONG    WMS-16053 revised field mapping (CS01)          */  
/* 2021-04-08 1.2  Mingle     WMS-16760 modify logic(ML01)                    */           
/******************************************************************************/                
                  
CREATE PROC [dbo].[isp_Bartender_CN_PVHLBL1_GetParm]                      
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
      @c_ExecArguments   NVARCHAR(4000)
      
   DECLARE @d_Trace_StartTime   DATETIME,   
           @d_Trace_EndTime     DATETIME,  
           @c_Trace_ModuleName  NVARCHAR(20),   
           @d_Trace_Step1       DATETIME,   
           @c_Trace_Step1       NVARCHAR(20),  
           @c_UserName          NVARCHAR(20),
           @c_sku               NVARCHAR(20),
           
           @c_GetPickslipno NVARCHAR(20),
           @c_GetMINSKU     NVARCHAR(20),
           @c_FirstOrderkey NVARCHAR(20),
           @c_countrycode   NVARCHAR(20),
           @c_OrdGRP        NVARCHAR(20), 
           @c_skucategory   NVARCHAR(20),
           @n_ctnrec        INT,
           @c_htscode       NVARCHAR(10),
           @n_Copy          INT

   SET @d_Trace_StartTime = GETDATE()  
   SET @c_Trace_ModuleName = ''  
        
   -- SET RowNo = 0             
   SET @c_SQL = ''   
   SET @c_SQLJOIN = ''        

   IF ISNULL(@parm04,'') = ''
   BEGIN
         SET @c_countrycode = ''
         SET @c_OrdGRP = ''
         SET @c_skucategory = ''
         SET @n_ctnrec = 0
         SET @c_htscode = ''
         SET @n_Copy = 1

         SELECT @c_GetPickslipno = pak.pickslipno
               ,@c_GetMINSKU = min(pd.sku)
               ,@c_FirstOrderkey = pak.FirstOrderkey
         FROM (
               SELECT PickslipNo    = ISNULL(PH1.PickslipNo, PH2.PickslipNo)
                    , FirstOrderkey = MIN(OH.Orderkey)
                 FROM dbo.ORDERS           OH (NOLOCK)
                 LEFT JOIN dbo.PACKHEADER  PH1(NOLOCK) ON OH.Orderkey = PH1.Orderkey AND PH1.Orderkey<>''
                 LEFT JOIN dbo.PACKHEADER  PH2(NOLOCK) ON OH.Loadkey = PH2.Loadkey AND OH.Loadkey<>'' AND ISNULL(PH2.Orderkey,'')=''
                WHERE OH.Storerkey = @Parm01
                  AND ISNULL(PH1.PickslipNo, PH2.PickslipNo) IS NOT NULL
               GROUP BY ISNULL(PH1.PickslipNo, PH2.PickslipNo)
            ) PAK
         JOIN dbo.PACKDETAIL PD  (NOLOCK) ON PAK.PickslipNo = PD.PickslipNo
         WHERE pd.labelno = @Parm02
         GROUP BY pak.pickslipno,pak.FirstOrderkey
          
         IF @b_debug = '1'
         BEGIN
           select @c_GetPickslipno '@c_GetPickslipno', @c_GetMINSKU '@c_GetMINSKU',@c_FirstOrderkey '@c_FirstOrderkey'
         END

         SELECT @c_countrycode = ST.isocntrycode,
                @c_OrdGRP = OH.OrderGroup 
         FROM ORDERS OH WITH (NOLOCK) 
         LEFT JOIN Storer ST WITH (NOLOCK) ON ST.ConsigneeFor = OH.StorerKey 
                                           AND substring(ST.storerkey,5, len(ST.storerkey) - 4) = OH.consigneekey
         WHERE OH.Storerkey = @Parm01
         AND OH.Orderkey = @c_FirstOrderkey

         IF @b_debug = '1'
         BEGIN
            select @c_countrycode '@c_countrycode',@c_OrdGRP '@c_OrdGRP'
         END

         SELECT @c_skucategory = C.UDF01
         FROM SKU S WITH (NOLOCK)
         LEFT JOIN CODELKUP C WITH (NOLOCK) ON C.listname = 'QHWORDTP' AND C.Storerkey = @Parm01
                                            AND C.code = LEFT(S.busr2,2)
         WHERE S.storerkey = @Parm01 AND S.sku=@c_GetMINSKU
         
         IF @b_debug = '1'
         BEGIN 
            SELECT @c_skucategory '@c_skucategory'
         END

         SELECT @n_ctnrec = count(1)
         FROM Codelkup C2 WITH (NOLOCK)
         WHERE C2.listname = 'PVHPXLBL'
         AND C2.Short = @c_skucategory
         AND C2.udf01=@c_countrycode AND C2.udf02=@c_OrdGRP
         AND C2.storerkey = @Parm01 AND C2.code2='1'

         IF @b_debug = '1'
         BEGIN
           select @n_ctnrec '@n_ctnrec'
         END
       
            IF @n_ctnrec = 0 and @c_OrdGRP <> 'W'      --(ML01)
            BEGIN  
                  SELECT @c_htscode = LEFT(SC.data,2)
                  FROM SKUConfig SC WITH (NOLOCK)
                  WHERE SC.Storerkey = @Parm01
                  AND SC.ConfigType = 'HTSCODE-PVH'
                  AND SC.SKU = @c_GetMINSKU

                  IF @b_debug = '1'
                  BEGIN 
                     select @c_htscode '@c_htscode'
                  END

                 IF EXISTS(SELECT 1 FROM CODELKUP C WITH (NOLOCK) 
                           WHERE C.listname = 'PVHPXLBL' AND C.short = @c_htscode AND C.udf01 = @c_countrycode
                           AND C.udf02 = @c_OrdGRP AND C.storerkey = @parm01 AND C.code2 = '2')
                 BEGIN
                    SET @n_Copy = 2
                 END
                 ELSE
                 BEGIN
                     SET @n_Copy = 1
                 END
                  IF @b_debug = '1'
                  BEGIN 
                     select @n_Copy '@n_Copy'
                  END

                SET @c_SQLJOIN = ' SELECT DISTINCT PARM1=PD.storerkey,PARM2=PD.labelno,PARM3=PD.SKU,PARM4=CAST(SUM(PD.Qty*@n_Copy) as NVARCHAR(10)),PARM5=''ByLabelNo'',' + CHAR(13) +
                                 ' PARM6= '''',PARM7='''',PARM8='''',PARM9='''',PARM10='''',Key1=''Storerkey'',Key2=''labelno'',Key3='''',Key4='''',Key5='''' ' + CHAR(13) +
                                 ' FROM PACKDETAIL PD WITH (NOLOCK)  ' + CHAR(13) +
                                 ' WHERE PD.storerkey = @Parm01 '+ CHAR(13) +
                                 ' AND PD.labelno = @Parm02 ' + CHAR(13) +
                                 ' GROUP BY PD.storerkey,PD.labelno,PD.sku'
            END
   END
   ELSE
   BEGIN
      SET @c_SQLJOIN = ' SELECT DISTINCT PARM1=@Parm01,PARM2=@Parm02,PARM3=@Parm03,PARM3=@Parm04,PARM5=''BySKU'',' + CHAR(13) +
                       ' PARM6= '''',PARM7='''',PARM8='''',PARM9='''',PARM10='''',Key1=''Storerkey'',Key2=''labelno'',Key3='''',Key4='''',Key5='''' '
   END   
    
   SET @c_ExecArguments = N' @parm01          NVARCHAR(80),'
                         + ' @parm02          NVARCHAR(80),' 
                         + ' @parm03          NVARCHAR(80),'
                         + ' @parm04          NVARCHAR(80),'
                         + ' @parm05          NVARCHAR(80),'
                         + ' @n_Copy          INT'
                       
       
   SET @c_SQL = @c_SQLJOIN + CHAR(13) 
   
   IF @b_debug = 1   
      PRINT @c_SQL
      
   EXEC sp_executesql   @c_SQL  
                      , @c_ExecArguments  
                      , @parm01  
                      , @parm02 
                      , @parm03 
                      , @parm04
                      , @parm05
                      , @n_Copy
                       
EXIT_SP:    
  
   SET @d_Trace_EndTime = GETDATE()  
   SET @c_UserName = SUSER_SNAME()  
                                  
END -- procedure   


GO