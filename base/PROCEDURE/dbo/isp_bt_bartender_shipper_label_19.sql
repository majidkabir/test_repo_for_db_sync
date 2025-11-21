SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/                 
/* Copyright: LFL                                                             */                 
/* Purpose: WMS-13484 - DYSON ZTO Ship Label                                  */      
/*        : Copy and modify from isp_BT_Bartender_Shipper_Label_1             */              
/*                                                                            */                 
/* Modifications log:                                                         */                 
/*                                                                            */                 
/* Date       Rev  Author     Purposes                                        */                 
/* 2020-06-29 1.0  WLChooi    Created(WMS-13484)                              */ 
/* 2020-07-01 1.1  WLChooi    Bug Fix (WL01)                                  */       
/* 2020-10-27 1.1  CSCHONG    Performance tunning (CS01)                      */    
/******************************************************************************/                                  
CREATE PROC [dbo].[isp_BT_Bartender_Shipper_Label_19]     
(  @c_Sparm1            NVARCHAR(250),              
   @c_Sparm2            NVARCHAR(250),              
   @c_Sparm3            NVARCHAR(250), 
   @c_Sparm4            NVARCHAR(250)='',  
   @c_Sparm5            NVARCHAR(250)='',    
   @c_Sparm6            NVARCHAR(250)='',  
   @c_Sparm7            NVARCHAR(250)='', 
   @c_Sparm8            NVARCHAR(250)='',  
   @c_Sparm9            NVARCHAR(250)='', 
   @c_Sparm10           NVARCHAR(250)='',                
   @b_debug             INT = 0                         
)                      
AS                      
BEGIN                      
   SET NOCOUNT ON                 
   SET ANSI_NULLS OFF                
   SET QUOTED_IDENTIFIER OFF                 
   SET CONCAT_NULL_YIELDS_NULL OFF                
   --SET ANSI_WARNINGS OFF                    --(CS21)                
                              
   DECLARE                  
      @c_OrderKey        NVARCHAR(10),                    
      @c_ExternOrderKey  NVARCHAR(10),              
      @c_Deliverydate    DATETIME,              
      @c_ConsigneeKey    NVARCHAR(15),              
      @c_Company         NVARCHAR(45),              
      @C_Address1        NVARCHAR(45),              
      @C_Address2        NVARCHAR(45),              
      @C_Address3        NVARCHAR(45),              
      @C_Address4        NVARCHAR(45),              
      @C_BuyerPO         NVARCHAR(20),              
      @C_notes2          NVARCHAR(4000),              
      @c_OrderLineNo     NVARCHAR(5),              
      @c_SKU             NVARCHAR(20),              
      @n_Qty             INT,              
      @c_PackKey         NVARCHAR(10),              
      @c_UOM             NVARCHAR(10),              
      @C_PHeaderKey      NVARCHAR(18),              
      @C_SODestination   NVARCHAR(30)  
        
   DECLARE @n_RowNo             INT,  
           @n_SumPickDetQty     INT,  
           @n_SumUnitPrice      INT,  
           @c_SQL               NVARCHAR(4000),  
           @c_SQLSORT           NVARCHAR(4000),  
           @c_SQLJOIN           NVARCHAR(4000),  
           @c_Udef04            NVARCHAR(80),  --(CS04)      
           @c_TrackingNo        NVARCHAR(20),  --(CS04)       
           @n_RowRef            INT,           --(CS04)      
           @c_CLong             NVARCHAR(250), --(CS05)      
           @c_ORDAdd            NVARCHAR(150), --(CS06)      
           @n_TTLPickQTY        INT,  
           @c_ShipperKey        NVARCHAR(15),  
           @n_PackInfoWgt       INT,              --(CS08)  
           @n_CntPickZone       INT,              --(CS08)  
           @c_UDF01             NVARCHAR(60),     --(CS12)  
           @c_ConsigneeFor      NVARCHAR(15),     --(CS14)  
           @c_Notes             NVARCHAR(80),     --(CS14)  
           @c_City              NVARCHAR(45),     --(CS14)  
           @c_GetCol55          NVARCHAR(100),    --(CS15)  
           @c_Col55             NVARCHAR(80),     --(CS15)  
           @c_ExecStatements    NVARCHAR(4000),   --(CS15)  
           @c_ExecArguments     NVARCHAR(4000),   --(CS15)  
           @c_Picknotes         NVARCHAR(100),    --(CS16)  
           @c_State             NVARCHAR(45),     --(CS20)  
           @c_Col35             NVARCHAR(80),     --(Cs23) 
           @c_StorerKey         NVARCHAR(15),     --(CS25)
           @c_Door              NVARCHAR(10),     --(CS25)
           @c_DeliveryNote      NVARCHAR(10),     --(CS25)
           @c_GetShipperKey     NVARCHAR(15),     --(CS25)
           @c_GetCodelkup       NVARCHAR(1),      --(CS25)  
           @c_CNotes            NVARCHAR(200),    --(CS25)    
           @c_Short             NVARCHAR(25),     --CS25  
           @c_SVAT              NVARCHAR(18),     --(CS27)     
           @c_Col39             NVARCHAR(80),     --(CS32) 
           @n_Getcol39          FLOAT,            --(CS32)
           @c_GetStorerKey      NVARCHAR(20),     --(CS32)
           @c_DocType           NVARCHAR(10),     --(CS32)
           @c_OHUdef01          NVARCHAR(20),     --(CS32)
           @c_Condition1        NVARCHAR(150),    --(CS33a)
           @c_Condition2        NVARCHAR(150)     --(CS33a)
          ,@n_Id                INT 
          
   DECLARE @d_Trace_StartTime   DATETIME,   
           @d_Trace_EndTime    DATETIME,  
           @c_Trace_ModuleName NVARCHAR(20),   
           @d_Trace_Step1      DATETIME,   
           @c_Trace_Step1      NVARCHAR(20),  
           @c_UserName         NVARCHAR(20)   
           
    /*CS34 start*/
   
   DECLARE   @d_starttime        datetime,
              @d_endtime          datetime,
              @d_Step1            datetime,
              @d_Step2            datetime,
              @d_Step3            datetime,
              @d_Step4            datetime,
              @d_Step5            datetime,
              @c_Col1             NVARCHAR(20),
              @c_Col2             NVARCHAR(20),
              @c_Col3             NVARCHAR(20),
              @c_Col4             NVARCHAR(20),
              @c_Col5             NVARCHAR(20),
              @c_TraceName        NVARCHAR(80),
              @n_UnitPrice        INT, 
              @c_PickSlipNo       NVARCHAR(10) = '',
              @c_EncryptPhoneNum  NVARCHAR(10) = 'N', 
              @c_JoinTable        NVARCHAR(4000) = '',
              @c_condition3       NVARCHAR(4000) = ''   --WL01
   
   /*CS34 End*/  
  
   SET @d_Trace_StartTime = GETDATE()  
   SET @c_Trace_ModuleName = '' 
   SET @d_step1 = GETDATE() -- (CS35) 
        
   -- SET RowNo = 0             
   SET @c_SQL = ''        
   SET @n_SumPickDetQty = 0            
   SET @n_SumUnitPrice = 0  
   SET @n_UnitPrice = 0
   
   SET @c_StorerKey = ''
   SET @c_Door = ''     
   SET @c_DeliveryNote = ''
   SET @c_GetCodelkup = 'N'    
   SET @c_SVAT = ''             --(CS27)  
   SET @c_condition1 =''        --(CS33a)
   SET @c_condition2 = ''       --(CS33a)
   SET @n_id = 1
              
   CREATE TABLE [#t_BartenderResult]     
   (  
    [ID]        [INT] ,--IDENTITY(1, 1) NOT NULL,  
    [Col01]     [NVARCHAR] (80) NULL,  
    [Col02]     [NVARCHAR] (80) NULL,  
    [Col03]     [NVARCHAR] (80) NULL,  
    [Col04]     [NVARCHAR] (80) NULL,  
    [Col05]     [NVARCHAR] (80) NULL,  
    [Col06]     [NVARCHAR] (80) NULL,  
    [Col07]     [NVARCHAR] (80) NULL,  
    [Col08]     [NVARCHAR] (80) NULL,  
    [Col09]     [NVARCHAR] (80) NULL,  
    [Col10]     [NVARCHAR] (80) NULL,  
    [Col11]     [NVARCHAR] (80) NULL,  
    [Col12]     [NVARCHAR] (80) NULL,  
    [Col13]     [NVARCHAR] (80) NULL,  
    [Col14]     [NVARCHAR] (80) NULL,  
    [Col15]     [NVARCHAR] (80) NULL,  
    [Col16]     [NVARCHAR] (80) NULL,  
    [Col17]     [NVARCHAR] (80) NULL,  
    [Col18]     [NVARCHAR] (80) NULL,  
    [Col19]     [NVARCHAR] (80) NULL,  
    [Col20]     [NVARCHAR] (80) NULL,  
    [Col21]     [NVARCHAR] (80) NULL,  
    [Col22]     [NVARCHAR] (80) NULL,  
    [Col23]     [NVARCHAR] (80) NULL,  
    [Col24]     [NVARCHAR] (80) NULL,  
    [Col25]     [NVARCHAR] (80) NULL,  
    [Col26]     [NVARCHAR] (80) NULL,  
    [Col27]     [NVARCHAR] (80) NULL,  
    [Col28]     [NVARCHAR] (80) NULL,  
    [Col29]     [NVARCHAR] (80) NULL,  
    [Col30]     [NVARCHAR] (80) NULL,  
    [Col31]     [NVARCHAR] (80) NULL,  
    [Col32]     [NVARCHAR] (80) NULL,  
    [Col33]     [NVARCHAR] (80) NULL,  
    [Col34]     [NVARCHAR] (80) NULL,  
    [Col35]     [NVARCHAR] (80) NULL,  
    [Col36]     [NVARCHAR] (80) NULL,  
    [Col37]     [NVARCHAR] (80) NULL,  
    [Col38]     [NVARCHAR] (80) NULL,  
    [Col39]     [NVARCHAR] (80) NULL,  
    [Col40]     [NVARCHAR] (80) NULL,  
    [Col41]     [NVARCHAR] (80) NULL,  
    [Col42]     [NVARCHAR] (80) NULL,  
    [Col43]     [NVARCHAR] (80) NULL,  
    [Col44]     [NVARCHAR] (80) NULL,  
    [Col45]     [NVARCHAR] (80) NULL,  
    [Col46]     [NVARCHAR] (80) NULL,  
    [Col47]     [NVARCHAR] (80) NULL,  
    [Col48]     [NVARCHAR] (80) NULL,  
    [Col49]     [NVARCHAR] (80) NULL,  
    [Col50]     [NVARCHAR] (80) NULL,  
    [Col51]     [NVARCHAR] (80) NULL,  
    [Col52]     [NVARCHAR] (80) NULL,  
    [Col53]     [NVARCHAR] (80) NULL,  
    [Col54]     [NVARCHAR] (80) NULL,  
    [Col55]     [NVARCHAR] (80) NULL,  
    [Col56]     [NVARCHAR] (80) NULL,  
    [Col57]     [NVARCHAR] (80) NULL,  
    [Col58]     [NVARCHAR] (80) NULL,  
    [Col59]     [NVARCHAR] (80) NULL,  
    [Col60]     [NVARCHAR] (80) NULL  
   )       
     
   --CREATE TABLE [@t_PICK]  
   DECLARE @t_PICK AS TABLE 
   (  
    [ID]             [INT] IDENTITY(1, 1) NOT NULL,  
    [OrderKey]       [NVARCHAR] (80) NULL,  
    [TTLPICKQTY]     [INT] NULL,  
    [PickZone]       [INT] NULL,  
    [picknotes]      [nvarchar] (100) NULL   --(CS16)  
   )      
   
   IF @b_debug = 1  
   BEGIN  
      PRINT 'start ' +   @c_Sparm4
   END      
   --CS01 START
   --SELECT TOP 1 @c_StorerKey = ORD.StorerKey
   --FROM ORDERS ORD WITH (NOLOCK)
   --WHERE ORD.loadkey = @c_Sparm1
   
   SELECT TOP 1 @c_StorerKey = ORD.StorerKey
   FROM loadplandetail (NOLOCK) 
   JOIN  ORDERS ORD WITH (NOLOCK) ON ORD.orderkey = loadplandetail.orderkey
   WHERE loadplandetail.loadkey = @c_Sparm1
   --CS01 END

   IF ISNULL(RTRIM(@c_Sparm2),'') <> ''
   BEGIN
      SET @c_condition1 = ' AND ORD.OrderKey =RTRIM(@c_Sparm2)'
   END   
   ELSE 
   BEGIN
      SET @c_condition1 = ' AND ORD.LoadKey = @c_Sparm1 '      

      IF ISNULL(RTRIM(@c_Sparm3),'') <> ''
      BEGIN
         SET @c_condition2 = ' AND ORD.ShipperKey =RTRIM(@c_Sparm3)'
      END          
   END
   
   SET @c_JoinTable = ' JOIN PACKHEADER PH (NOLOCK) ON PH.Orderkey = ORD.Orderkey JOIN PACKDETAIL PD (NOLOCK) ON PD.Pickslipno = PH.Pickslipno '
   
   IF ISNULL(RTRIM(@c_Sparm5),'') <> '' AND ISNULL(RTRIM(@c_Sparm6),'') <> ''   --WL01
      SET @c_condition3 = ' AND PD.CartonNo >= CONVERT(INT,@c_Sparm5) AND PD.CartonNo <= CONVERT(INT,@c_Sparm6) '   --WL01
 
   IF ISNULL(@c_Sparm4,'0') > '0'        
   BEGIN          
      IF @c_Sparm4='1'            
      BEGIN          
         SET @c_SQLJOIN = +' SELECT DISTINCT @n_id,ORD.loadkey,ORD.orderkey,ORD.externorderkey,ORD.type,buyerpo,salesman,ORD.facility,STO.Secondary,'    --8   --WL01           
                          + CHAR(13) +           
                          +'STO.Company,STO.SUSR1,STO.SUSR2,(STO.Address1+STO.Address2+STO.Address3),SUBSTRING(ORD.Notes, 1, 80),'''',ORD.StorerKey,STO.State,'  --8  --(CS12)       
                          + CHAR(13) +          
                          +'STO.City,STO.Zip,STO.Contact1,STO.Phone1,STO.phone2,ORD.Consigneekey,ORD.c_Company,ORD.c_Address1,'+ CHAR(13) +          
                          +'ISNULL(ORD.c_Address2,''''),ISNULL(ORD.C_Address3,''''),ORD.C_Address4,ORD.C_State,ORD.C_City,ORD.C_Zip,ORD.C_Contact1,ORD.C_Phone1,'          
                          +'ISNULL(ORD.C_Phone2,''''),CASE WHEN STO.VAT=''LEV'' THEN ORD.Notes2 ELSE ORD.M_Company END,ORD.Userdefine01,'--ORD.Userdefine02,'          --(CS31)   --CS33
                          + 'CASE WHEN STO.StorerKey = ''18354'' THEN ORDIF.DeliveryCategory ELSE ORD.Userdefine02 END, '                                        --CS33
                          +' CASE WHEN STO.VAT=''ITX'' THEN ORD.Door ELSE  ORD.Userdefine03 END,PD.LabelNo,ORD.Userdefine05,' --ORD.PmtTerm,'     --CS19 --CS28      
                          + CHAR(13) +   
                          +' CASE WHEN STO.StorerKey IN (''ANF'',''18354'',''18467'') THEN ORD.DeliveryNote Else ORD.PmtTerm END ,'      --CS28  --CS33  --WL03
                          +'ORD.InvoiceAmount,'''','''','           
                          +'ORD.ShipperKey,STO.B_Company,(STO.B_Address1+STO.B_Address2+STO.B_Address3),STO.B_Contact1,STO.B_Phone1,ORD.DeliveryPlace,'''', '  --50  --CS03      
                          +' '''',ORD.M_Address1,ORD.M_Address2,ORD.M_City,'''','''',ORD.Priority,ORD.Userdefine10,LOC.Logicallocation,LOC.LOC '      --CS07   --CS09 --CS10 --CS13    
                          + CHAR(13) +            
                          + ' FROM ORDERS ORD WITH (NOLOCK) INNER JOIN ORDERDETAIL ORDDET WITH (NOLOCK)  ON ORD.ORDERKEY = ORDDET.ORDERKEY   '       
                          + ' INNER JOIN STORER STO WITH (NOLOCK) ON STO.StorerKey = ORD.StorerKey '        
                          + ' INNER JOIN PICKDETAIL PD WITH (NOLOCK) ON PD.OrderKey = ORD.OrderKey and PD.OrderLineNumber = ORDDET.OrderLineNumber'        
                          + ' INNER JOIN LOC LOC WITH (NOLOCK) ON LOC.LOC = PD.LOC '    --CS07   
                          + ' LEFT JOIN ORDERINFO ORDIF WITH (NOLOCK) ON ORDIF.orderkey = ORD.Orderkey '                                    --CS33   
                          + @c_JoinTable
                          + ' WHERE ORD.StorerKey = @c_StorerKey '                          
      END           
      ELSE          
      BEGIN           
         SET @c_SQLJOIN = +' SELECT DISTINCT @n_id,ORD.loadkey,ORD.orderkey,ORD.externorderkey,ORD.type,buyerpo,salesman,ORD.facility,STO.Secondary,'    --8   --WL01           
                          + CHAR(13) +           
                          +'STO.Company,STO.SUSR1,STO.SUSR2,(STO.Address1+STO.Address2+STO.Address3),SUBSTRING(ORD.Notes, 1, 80),'''',ORD.StorerKey,STO.State,'  --8     --(CS12)   
                          + CHAR(13) +          
                          +'STO.City,STO.Zip,STO.Contact1,STO.Phone1,STO.phone2,ORD.Consigneekey,ORD.c_Company,ORD.c_Address1,'+ CHAR(13) +          
                          +'ISNULL(ORD.c_Address2,''''),ISNULL(ORD.C_Address3,''''),ORD.C_Address4,ORD.C_State,ORD.C_City,ORD.C_Zip,ORD.C_Contact1,ORD.C_Phone1,'          
                          +'ISNULL(ORD.C_Phone2,''''),CASE WHEN STO.VAT=''LEV'' THEN ORD.Notes2 ELSE ORD.M_Company END,'                      --(CS31)
                          +'ORD.Userdefine01,' --ORD.Userdefine02,'
                          +' CASE WHEN STO.StorerKey = ''18354'' THEN ORDIF.DeliveryCategory ELSE ORD.Userdefine02 END, '                                        --CS33
                          +' CASE WHEN STO.VAT=''ITX'' THEN ORD.Door ELSE  ORD.Userdefine03 END,PD.LabelNo,ORD.Userdefine05,'--ORD.PmtTerm,'   --CS19    --CS28
                          + CHAR(13) +
                          +' CASE WHEN STO.StorerKey IN (''ANF'',''18354'',''18467'') THEN ORD.DeliveryNote Else ORD.PmtTerm END ,'      --CS28  --CS33 
                          +'ORD.InvoiceAmount,'''','''','           
                          +'ORD.ShipperKey,STO.B_Company,(STO.B_Address1+STO.B_Address2+STO.B_Address3),STO.B_Contact1,STO.B_Phone1,ORD.DeliveryPlace,'''', '  --50 --CS03       
                          +' '''',ORD.M_Address1,ORD.M_Address2,ORD.M_City,'''','''',ORD.Priority,ORD.Userdefine10,'''','''' '   --CS10    --CS13    
                          + CHAR(13) +            
                          + ' FROM ORDERS ORD WITH (NOLOCK) '      
                          + ' INNER JOIN STORER STO WITH (NOLOCK) ON STO.StorerKey = ORD.StorerKey '    
                          + ' LEFT JOIN ORDERINFO ORDIF WITH (NOLOCK) ON ORDIF.orderkey = ORD.Orderkey '                                    --CS33     
                          + @c_JoinTable
                          + ' WHERE ORD.StorerKey = @c_StorerKey '               
      END         
   END        
   ELSE        
   BEGIN        
      SET @c_SQLJOIN = +' SELECT DISTINCT @n_id,ORD.loadkey,ORD.orderkey,ORD.externorderkey,ORD.type,buyerpo,salesman,ORD.facility,STO.Secondary,'    --8   --WL01       
                       + CHAR(13) +           
                       +'STO.Company,STO.SUSR1,STO.SUSR2,(STO.Address1+STO.Address2+STO.Address3),SUBSTRING(ORD.Notes, 1, 80),'''',ORD.StorerKey,STO.State,'  --8  --(CS12)      
                       + CHAR(13) +          
                       +'STO.City,STO.Zip,STO.Contact1,STO.Phone1,STO.phone2,ORD.Consigneekey,ORD.c_Company,ORD.c_Address1,'+ CHAR(13) +          
                       +'ISNULL(ORD.c_Address2,''''),ISNULL(ORD.C_Address3,''''),ORD.C_Address4,ORD.C_State,ORD.C_City,ORD.C_Zip,ORD.C_Contact1,ORD.C_Phone1,'          
                       +'ISNULL(ORD.C_Phone2,''''),CASE WHEN STO.VAT=''LEV'' THEN ORD.Notes2 ELSE ORD.M_Company END,'                      --(CS31)
                       +'ORD.Userdefine01,'--ORD.Userdefine02,
                       +' CASE WHEN STO.StorerKey = ''18354'' THEN ORDIF.DeliveryCategory ELSE ORD.Userdefine02 END, '                                        --CS33
                       +' CASE WHEN STO.VAT=''ITX'' THEN ORD.Door ELSE  ORD.Userdefine03 END,PD.LabelNo,ORD.Userdefine05,' --ORD.PmtTerm,'     --CS19   --CS28    
                       + CHAR(13) + 
                       +' CASE WHEN STO.StorerKey IN (''ANF'',''18354'',''18467'') THEN ORD.DeliveryNote Else ORD.PmtTerm END ,'      --CS28  --CS33        --WL03
                       +'ORD.InvoiceAmount,'''','''','           
                       +'ORD.ShipperKey,STO.B_Company,(STO.B_Address1+STO.B_Address2+STO.B_Address3),STO.B_Contact1,STO.B_Phone1,ORD.DeliveryPlace,'''', '  --50  --CS03      
                       +' '''',ORD.M_Address1,ORD.M_Address2,ORD.M_City,'''','''',ORD.Priority,ORD.Userdefine10,'''','''' '     --CS10     --CS13  
                       + CHAR(13) +            
                       + ' FROM ORDERS ORD (NOLOCK) JOIN STORER STO (NOLOCK) ON STO.StorerKey = ORD.StorerKey '  
                       + ' LEFT JOIN ORDERINFO ORDIF WITH (NOLOCK) ON ORDIF.orderkey = ORD.Orderkey '                                    --CS33     
                       + @c_JoinTable   
                       + ' WHERE ORD.StorerKey = @c_StorerKey '             
   END        
          
   IF @b_debug = 1  
   BEGIN  
      PRINT @c_SQLJOIN  
   END               
              
   SET @c_SQL='INSERT INTO #t_BartenderResult (ID,Col01,Col02,Col03,Col04,Col05, Col06,Col07,Col08,Col09'  + CHAR(13) +           
             +',Col10,Col11,Col12,Col13,Col14,Col15,Col16,Col17,Col18,Col19,Col20,Col21,Col22'  + CHAR(13) +           
             +',Col23,Col24,Col25,Col26,Col27,Col28,Col29,Col30,Col31,Col32,Col33,Col34' + CHAR(13) +           
             +',Col35,Col36,Col37,Col38,Col39,Col40,Col41,Col42,Col43,Col44'  + CHAR(13) +           
             +',Col45,Col46,Col47,Col48,Col49,Col50,Col51,Col52,Col53,Col54'+ CHAR(13) +           
             + ',Col55,Col56,Col57,Col58,Col59,Col60) '          
    
   SET @c_SQL = @c_SQL + @c_SQLJOIN +  CHAR(13) + @c_condition1  + CHAR(13) + @c_condition2 + CHAR(13) + @c_condition3   --WL01
     
   SET @c_ExecArguments = N' @c_Sparm1           NVARCHAR(80)'    
                        + ', @c_Sparm2           NVARCHAR(80)'    
                        + ', @c_Sparm3           NVARCHAR(80)'
                        + ', @c_Sparm4           NVARCHAR(80)' 
                        + ', @c_Sparm5           NVARCHAR(80)' 
                        + ', @c_Sparm6           NVARCHAR(80)' 
                        + ', @c_StorerKey        NVARCHAR(10)'  
                        + ', @n_id               INT' 
                                          
   EXEC sp_ExecuteSql     @c_SQL     
                        , @c_ExecArguments    
                        , @c_Sparm1    
                        , @c_Sparm2    
                        , @c_Sparm3   
                        , @c_Sparm4
                        , @c_Sparm5
                        , @c_Sparm6
                        , @c_StorerKey
                        , @n_id
                        
     
   --EXEC sp_executesql @c_SQL      
   --CS33 END    
        
   IF @b_debug = 1  
   BEGIN  
      PRINT @c_SQL  
   END  
  
   IF @b_debug = 1  
   BEGIN  
      SELECT *  
      FROM   #t_BartenderResult 
   END 
   
   SET @d_step1 = GETDATE() - @d_step1 -- (CS34)
   SET @d_step2 = GETDATE() -- (CS34)      
            
   DECLARE CUR_RowNoLoop CURSOR LOCAL FAST_FORWARD READ_ONLY FOR                           
   SELECT DISTINCT Col02,col38 from #t_BartenderResult          
       
   OPEN CUR_RowNoLoop            
       
   FETCH NEXT FROM CUR_RowNoLoop INTO @c_OrderKey,@c_Udef04         
         
   WHILE @@FETCH_STATUS <> -1            
   BEGIN         
      SET @c_GetStorerKey = ''
      SET @c_DocType  = '' 
      SET @c_OHUdef01 = ''
        
      SELECT @c_GetStorerKey = StorerKey
            ,@c_DocType  = Type
            ,@c_OHUdef01 = UserDefine01
      FROM   ORDERS WITH (NOLOCK)  
      WHERE  OrderKey = @c_OrderKey  
      
      SET @c_SVAT = ''
      
      SELECT @c_SVAT = s.VAT
      FROM STORER AS s WITH (NOLOCK) 
      WHERE s.StorerKey = @c_GetStorerKey
      
      SET @c_PickSlipNo = ''
      SELECT TOP 1 @c_PickSlipNo = ph.PickSlipNo
      FROM PackHeader AS ph WITH (NOLOCK)
      WHERE ph.OrderKey = @c_OrderKey
      
      IF @b_debug='1'        
      BEGIN        
         PRINT @c_OrderKey           
      END        
      
      IF @c_Sparm4 < '8'  
      BEGIN  
         SELECT @n_SumPickDetQty = SUM(QTY),  
                @n_SumUnitPrice = SUM(QTY * ORDDET.Unitprice)  
         FROM   PICKDETAIL PD WITH (NOLOCK)  
         JOIN ORDERDETAIL ORDDET WITH (NOLOCK)  
                    ON PD.OrderKey = ORDDET.OrderKey  
                   AND PD.OrderLineNumber = ORDDET.OrderLineNumber  
         WHERE  PD.OrderKey = @c_OrderKey  
      END  
      ELSE  
      BEGIN  
         SELECT @n_SumPickDetQty = SUM(QTY),  
                @n_SumUnitPrice  = SUM(QTY * ORDDET.Unitprice), 
                @n_cntPickzone   = COUNT(DISTINCT l.pickzone) 
         FROM   PICKDETAIL PD WITH (NOLOCK)  
         JOIN ORDERDETAIL ORDDET WITH (NOLOCK)  
                      ON  PD.OrderKey = ORDDET.OrderKey  
                      AND PD.OrderLineNumber = ORDDET.OrderLineNumber  
         JOIN LOC L WITH (NOLOCK)  
                      ON  L.LOC = PD.LOC  
         WHERE  PD.OrderKey = @c_OrderKey  
         
         SELECT TOP 1 @c_picknotes = PD.notes   
         FROM   PICKDETAIL PD WITH (NOLOCK)  
         WHERE  PD.OrderKey = @c_OrderKey  
      END /*CS11 END*/    
  
      SELECT @n_PackInfoWgt = SUM(PKI.Weight), 
             @c_Col35 = CASE WHEN @c_SVAT = 'ITX' 
                        THEN CAST(SUM(CAST(PKI.[Cube] as NUMERIC(6,6))) as NVARCHAR(30)) 
                        ELSE @c_OHUdef01 
                        END
      FROM   PACKINFO PKI WITH (NOLOCK)    
      WHERE  PKI.Pickslipno = @c_PickSlipNo     

      /*CS32 Start*/  
      SET @c_Col39=''
      SET @n_getcol39   = 0      
      
      IF @c_GetStorerKey = 'ANF' AND @c_DocType = 'DTC' AND @c_OHUdef01='COD'
      BEGIN   
         SELECT @n_getcol39 = SUM(QTY * ORDDET.Unitprice)
                            + SUM(CASE WHEN ISNUMERIC(ORDDET.UserDefine05) = 1 THEN CAST(ORDDET.UserDefine05 AS FLOAT) ELSE 0 END) 
                            + SUM(ORDDET.ExtendedPrice)
                            + SUM(ORDDET.Tax01)
                            + SUM(CASE WHEN ISNUMERIC(ORDDET.UserDefine06) = 1 THEN CAST(ORDDET.UserDefine06 AS FLOAT) ELSE 0 END) 
         FROM ORDERDETAIL ORDDET(NOLOCK)
         JOIN PICKDETAIL PD(NOLOCK) ON  PD.OrderKey = ORDDET.OrderKey  
                                     AND PD.OrderLineNumber = ORDDET.OrderLineNumber  
         WHERE  ORDDET.OrderKey = @c_OrderKey  
   
         SET @c_Col39 = CONVERT(NVARCHAR(50),@n_getcol39)   
      END     
             
      UPDATE #t_BartenderResult            
      SET Col42 = @n_SumPickDetQty,   
          Col43 = @n_SumUnitPrice,  
          Col56 = @n_PackInfoWgt,    --(CS08) 
          Col35 = @c_Col35,          --(CS23)     
          Col39 = CASE WHEN ISNULL(@c_Col39,'') <> '' THEN @c_Col39 ELSE Col39 END          --(CS32)
      WHERE Col02=@c_OrderKey         
   
      INSERT INTO @t_PICK (OrderKey,TTLPICKQTY,PickZone,picknotes)      
      VALUES (@c_OrderKey,convert(int,@n_SumPickDetQty),ISNULL(@n_cntPickzone,0),@c_picknotes)   --(CS16)  
   
      IF @b_Debug = '1'    
      BEGIN    
         SELECT 'Pick'  
         SELECT *    
         FROM @t_PICK  
      END    
    
      FETCH NEXT FROM CUR_RowNoLoop INTO @c_OrderKey,@c_Udef04         
   END -- While             
   CLOSE CUR_RowNoLoop            
   DEALLOCATE CUR_RowNoLoop    
   
   
   SET @d_step2 = GETDATE() - @d_step2 -- (CS34)
   SET @d_step3 = GETDATE()            -- (CS34)         
      
   SET @c_ORDAdd = ''   
     
   DECLARE CUR_UpdateRec CURSOR LOCAL FAST_FORWARD READ_ONLY FOR              
   SELECT DISTINCT Col02     
   FROM #t_BartenderResult          
    
   OPEN CUR_UpdateRec            
    
   FETCH NEXT FROM CUR_UpdateRec INTO @c_OrderKey         
      
   WHILE @@FETCH_STATUS <> -1            
   BEGIN       
      SET @c_ShipperKey = ''    
      SET @c_ORDAdd = ''    
          
      SELECT @c_ORDAdd = RTRIM(ORD.C_State) + ' ' + RTRIM(ORD.C_City) + ' ' + RTRIM(ORD.C_Address1)   
            ,@c_City   = RTRIM(ORD.C_City)          --(CS20)  
            ,@c_State  = RTRIM(ORD.C_State)         --(CS20)  
            ,@c_Address1 = RTRIM(ORD.C_Address1)    --(CS20) 
            ,@c_StorerKey = ORD.StorerKey
            ,@c_Door      = ORD.Door
            ,@c_DeliveryNote = ORD.DeliveryNote
            ,@c_GetShipperKey = ORD.ShipperKey
            ,@c_ConsigneeKey  = ORD.ConsigneeKey
      FROM ORDERS ORD WITH (NOLOCK)      
      WHERE ORD.Orderkey =   @c_OrderKey    

      SET @c_ConsigneeFor = ''
      SELECT @c_ConsigneeFor = ISNULL(ConsigneeFor,'')  
      FROM  Storer S WITH (NOLOCK)    
      WHERE S.StorerKey= @c_GetShipperKey 
      
      --WL02 Start
      SELECT @c_EncryptPhoneNum = ISNULL(Short,'N')
      FROM CODELKUP (NOLOCK)
      WHERE LISTNAME = 'REPORTCFG' AND CODE = 'EncryptPhoneNumber'
      AND Storerkey = @c_StorerKey AND CODE2 = @c_GetShipperKey
      --WL02 End
      
      IF @b_debug = '1'      
      BEGIN       
         PRINT ' ORD address combine : ' + @c_ORDAdd + ' with orderkey : ' + @c_OrderKey      
      END    
      
      SET @c_CLong = ''         
      /*CS14 start*/       
      IF @b_debug='1'  
      BEGIN  
         Print ' ConsigneeFor : ' + @c_ConsigneeFor  
      END  
      
      IF @c_ConsigneeFor = 'A'   
      BEGIN  
         SELECT TOP 1 @c_cnotes = c.notes,
                      @c_short = C.short 
         FROM Codelkup C WITH (NOLOCK)   
         WHERE C.short =  @c_GetShipperKey      
           AND C.Listname='COURIERMAP'     
           AND C.UDF01='ELABEL'   
         
         SELECT TOP 1    
            @c_CLong = C.Long  
         FROM Codelkup C WITH (NOLOCK)     
         WHERE C.short =  @c_GetShipperKey      
         AND C.Listname='COURIERMAP'     
         AND C.UDF01='ELABEL'        
         AND c.notes like N'%' + @c_City + '%'  
      
         IF @b_debug='1'  
         BEGIN  
            Print ' c_long : ' + @c_CLong  
         END  
      
         IF ISNULL(@c_CLong,'') = ''  
         BEGIN              
            --SELECT TOP 1    
            --      @c_City = Ord.c_city  
            -- FROM ORDERS ORD WITH (NOLOCK)   
            -- WHERE ORD.Orderkey =  @c_OrderKey  
            -- AND  ORD.ShipperKey = @c_short
            --                                   
             SET @c_CLong = @c_City  
         END
          
         IF @b_debug='1'  
         BEGIN  
            Print ' c_city : ' + @c_City  
         END  
      END  
      ELSE  
      BEGIN    
         SELECT TOP 1    
            @c_CLong = C.Long      
         FROM Codelkup C WITH (NOLOCK)     
         WHERE C.Short=@c_GetShipperKey
         AND C.Listname='COURIERMAP'     
         AND C.UDF01='ELABEL'        
         AND c.Notes like N'%'+@c_State+'%' and c.Notes2 like N'%'+@c_City+'%' and c.Description like N'%'+@c_Address1+'%'
           
         IF @b_debug='1'  
         BEGIN  
            Print ' c_long : ' +  @c_CLong
         END  
      END    
      /*CS14 End*/      
      
      SET @c_notes2 = ''   
      
      /*CS27 start*/
      SET @c_SVAT = ''
      SELECT @c_SVAT = ISNULL(VAT,'')
      FROM STORER WITH (NOLOCK)
      WHERE StorerKey=@c_StorerKey
      
      SET @c_UDF01 = ''   
      SELECT TOP 1   
             @c_UDF01 = C.UDF01, 
             @c_notes2 = CASE WHEN @c_SVAT IN ('ITX','NIKE') AND @c_Door = '99' THEN  @c_DeliveryNote
                              ELSE C.Notes2 
                         END        
      FROM   Codelkup C WITH (NOLOCK)   
      WHERE C.Short = @c_GetShipperKey --(CS25)
        AND C.StorerKey = @c_StorerKey --(CS25)
        AND C.Listname = 'WSCourier' 
        ORDER BY (CASE WHEN @c_GetShipperKey = 'sf5' THEN C.NOTES2 END ) DESC,   --WL01
                 (CASE WHEN @c_GetShipperKey <> 'sf5' THEN C.NOTES2 END ) ASC    --WL01
      
      --IF @c_SVAT IN ('ITX','NIKE') AND @c_Door = '99'   --CS30
      --BEGIN
      --   SET @c_notes2= @c_DeliveryNote  
      --END
      --ELSE
      --BEGIN   
      --   SELECT TOP 1 @c_notes2 = C.Notes2         
      --   FROM   Codelkup C WITH (NOLOCK)   
      --   WHERE C.Short = @c_GetShipperKey  --(CS25)
      --   AND C.StorerKey = @c_StorerKey    --(CS25)
      --   AND C.Listname = 'WSCourier'     
      --END
      
      SET @c_GetCol55 = ''  
      
      SELECT TOP 1 @c_GetCol55 = C.Long  
      FROM Codelkup C WITH (NOLOCK)  
      WHERE C.listname='ELCOL55'  
      AND c.StorerKey = @c_StorerKey             --(CS25)
      
      IF @b_debug = '1'  
      BEGIN  
         PRINT ' Get Col55 : ' + @c_GetCol55   
      END     
      
      IF ISNULL(@c_GetCol55,'') = ''  
      BEGIN  
         SET @c_GetCol55 = 'Orders.IncoTerm'  
      END  
      SET @c_ExecStatements = ''  
      SET @c_ExecArguments = ''  
      
      SET @c_ExecStatements = N'SELECT @c_Col55 = ' + @c_GetCol55 + ' FROM ORDERS (NOLOCK) WHERE Orderkey = @c_OrderKey '  
      
      SET @c_ExecArguments = N'@c_GetCol55   NVARCHAR(80) '  
                             +',@c_OrderKey  NVARCHAR(30)'  
                             +',@c_Col55     NVARCHAR(20) OUTPUT'  
      
      EXEC sp_ExecuteSql @c_ExecStatements   
                        , @c_ExecArguments  
                        , @c_GetCol55       
                        , @c_OrderKey  
                        , @c_Col55 OUTPUT  
      
      IF @b_debug = '1'  
      BEGIN  
         PRINT ' Col55 : ' + @c_Col55   
      END    
      /*CS15 END*/  
      
      IF @b_debug = '1'  
      BEGIN  
            PRINT ' codelkup long : ' + @c_CLong + 'and notes2 : ' + @c_notes2 +   
            ' with orderkey : ' + @c_OrderKey  
      END     
      
      UPDATE #t_BartenderResult 
      SET Col50     = @c_CLong,  
          Col51     = @c_notes2, --(CS08)  
          Col14     = @c_UDF01,  --(CS12)  
          Col55     = @c_Col55,   --(CS15)  
          Col32     = CASE WHEN @c_EncryptPhoneNum = 'Y' AND ISNUMERIC(RIGHT(RTRIM(Col32),4)) = 1   --WL02 Start
                      THEN SUBSTRING(Col32,1,LEN(Col32) - 8) + '****' + RIGHT(RTRIM(Col32),4) ELSE Col32 END,
          Col33     = CASE WHEN @c_EncryptPhoneNum = 'Y' AND ISNUMERIC(RIGHT(RTRIM(Col33),4)) = 1 
                      THEN SUBSTRING(Col33,1,LEN(Col33) - 8) + '****' + RIGHT(RTRIM(Col33),4) ELSE Col33 END   --WL02 End
      WHERE  Col02  = @c_OrderKey        
      
      FETCH NEXT FROM CUR_UpdateRec INTO @c_OrderKey         
    
   END -- While              
   CLOSE CUR_UpdateRec            
   DEALLOCATE CUR_UpdateRec        
       
         
   SET @d_step3 = GETDATE() - @d_step3        -- (CS34)
   SET @d_step4 = GETDATE()                   -- (CS34)     
     
    
   /*CS07 End*/      
   IF ISNULL(@c_Sparm4 ,0) <> 0   
   BEGIN    
       IF @c_Sparm4 = '1'  
       BEGIN  
           SELECT R.*  
           FROM   #t_BartenderResult R  
           INNER  JOIN @t_PICK P   
                       ON  P.Orderkey = R.Col02  
           WHERE  (Col38  IS NOT NULL AND Col38 <> '')  --CS06  
           AND P.TTLPICKQTY = 1  
           ORDER BY Col59,  
                    Col60,  
                    Col02 --CS07  
       END    
       ELSE   
       /*CS11 Start*/     
       IF @c_Sparm4 > '1' AND @c_Sparm4 < '8'     --(CS29)
       BEGIN    
           SELECT R.*     
           FROM   #t_BartenderResult R    
           INNER JOIN @t_PICK P  
                      ON  P.Orderkey = R.Col02    
           WHERE  (Col38  IS NOT NULL AND Col38 <> '')   --CS06    
           AND    P.TTLPICKQTY > 1    
           ORDER BY Col02    
       END    
       ELSE 
       /*CS29 start*/
       IF @c_Sparm4 = '8' 
       BEGIN  
            SELECT R.*     
            FROM   #t_BartenderResult R     
            INNER JOIN @t_PICK P ON  P.Orderkey = R.Col02    
            WHERE  (Col38  IS NOT NULL AND Col38 <> '')   --CS06    
            AND    P.TTLPICKQTY > 1 AND P.PickZone>1  
            ORDER BY Col02  
       END
       ELSE
       /*CS29 End*/
       BEGIN  
      
       SELECT R.*     
           FROM   #t_BartenderResult R   
           INNER JOIN @t_PICK P  
                      ON  P.Orderkey = R.Col02    
           WHERE  (Col38  IS NOT NULL AND Col38 <> '')   --CS06    
           AND    P.TTLPICKQTY > 1 AND P.PickZone=1 --CS11   
           ORDER BY P.PickZone,         --(CS17)  
                    P.picknotes,        --(CS16)  
                    Col02,  
                    Col60    
       END  
       /*CS11 END*/  
   END    
   ELSE    
   BEGIN  
     SELECT *  
     FROM   #t_BartenderResult  
     WHERE  (Col38  IS NOT NULL AND Col38 <> '')     --CS06  
     ORDER BY Col02   
   END  
   
   SET @d_step4 = GETDATE() - @d_step4         -- (CS34)                 
                 
EXIT_SP:    
  
   SET @d_Trace_EndTime = GETDATE()  
   SET @c_UserName = SUSER_SNAME()  
   
   DROP TABLE #t_BartenderResult 
                                    
END -- procedure   



GO