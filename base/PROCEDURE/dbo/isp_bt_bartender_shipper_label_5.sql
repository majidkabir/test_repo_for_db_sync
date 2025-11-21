SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/                 
/* Copyright: IDS                                                             */                 
/* Purpose: BarTender Filter by ShipperKey.Duplicate from                     */
/*            isp_BT_Bartender_Shipper_Label_1 able to filter by cartonno     */   
/*            WMS-2374 CN-Nike SDC Bartender Courier Label                    */                          
/* Modifications log:                                                         */                 
/*                                                                            */                 
/* Date          Rev  Author     Purposes                                     */ 
/* 11-SEP-2017   1.1  CSCHONG    WMS-2906 - revise field mapping (CS01)       */   
/* 12-DEC-2017   1.1  WLCHOOI    WMS-3678 Updated mapping for col08 (WL01)    */                
/******************************************************************************/                
                  
CREATE PROC [dbo].[isp_BT_Bartender_Shipper_Label_5]                       
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
                              
   DECLARE                  
      @c_OrderKey        NVARCHAR(10),                    
      @c_ExternOrderKey  NVARCHAR(10),              
      @c_Deliverydate    DATETIME,              
      @c_ConsigneeKey    NVARCHAR(15),              
      @c_Company  NVARCHAR(45),              
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
          @n_SumPickDETQTY     INT,  
          @n_SumUnitPrice      INT,  
          @c_SQL               NVARCHAR(4000),  
          @c_SQLSORT           NVARCHAR(4000),  
          @c_SQLJOIN           NVARCHAR(4000),  
          @c_Udef04            NVARCHAR(80),        
          @c_TrackingNo        NVARCHAR(20),         
          @n_RowRef            INT,               
          @c_CLong             NVARCHAR(250),       
          @c_ORDAdd            NVARCHAR(150),      
          @n_TTLPickQTY        INT,  
          @c_ShipperKey        NVARCHAR(15),  
          @n_PackInfoWgt       INT,                
          @n_CntPickZone       INT,               
          @c_UDF01             NVARCHAR(60),      
          @c_consigneeFor      NVARCHAR(15),     
          @c_notes             NVARCHAR(80),       
          @c_City              NVARCHAR(45),      
          @c_GetCol55          NVARCHAR(100),      
          @c_Col55             NVARCHAR(80),       
          @c_ExecStatements    NVARCHAR(4000),     
          @c_ExecArguments     NVARCHAR(4000),    
          @c_picknotes         NVARCHAR(100),      
          @c_State             NVARCHAR(45),      
          @c_col35             NVARCHAR(80),      
          @c_storerkey         NVARCHAR(15),     
          @c_Door              NVARCHAR(10),     
          @c_deliveryNote      NVARCHAR(10),     
          @c_GetShipperKey     NVARCHAR(15),     
          @c_GetCodelkup       NVARCHAR(1),        
          @c_cNotes            NVARCHAR(200),      
          @c_short             NVARCHAR(25),      
          @c_SVAT              NVARCHAR(18),          
          @c_col39             NVARCHAR(80),     
          @n_getcol39          INT,              
          @c_getstorerkey      NVARCHAR(20),     
          @c_doctype           NVARCHAR(10),     
          @c_OHUdef01          NVARCHAR(20),
          @c_condition         NVARCHAR(150),
          @c_cartonNo          NVARCHAR(5),
          @c_GetCol53          NVARCHAR(100),      
          @c_Col53             NVARCHAR(80),
          @c_Col56             NVARCHAR(80),
          @c_col27             NVARCHAR(80),       --CS01
          @c_Col27Ext          NVARCHAR(10),       --CS01
          @c_MSKU              NVARCHAR(20),       --CS01
          @n_MQTY              INT,                --CS01 
          @c_Col27split        NVARCHAR(5),        --CS01 
          @n_CNTMSKU           INT,                --CS01
          @c_getcol27          NVARCHAR(80),       --CS01
          @n_id                INT                 --Cs01
          
  DECLARE @d_Trace_StartTime   DATETIME,   
           @d_Trace_EndTime    DATETIME,  
           @c_Trace_ModuleName NVARCHAR(20),   
           @d_Trace_Step1      DATETIME,   
           @c_Trace_Step1      NVARCHAR(20),  
           @c_UserName         NVARCHAR(20),
           @n_startCtn         INT,
           @n_EndCtn           INT
                
  
   SET @d_Trace_StartTime = GETDATE()  
   SET @c_Trace_ModuleName = ''  
        
    -- SET RowNo = 0             
    SET @c_SQL = ''        
    SET @n_SumPickDETQTY = 0            
    SET @n_SumUnitPrice = 0  

    SET @c_storerkey = ''
    SET @c_Door = ''     
    SET @c_deliveryNote = ''
    SET @c_GetCodelkup = 'N'    
    SET @c_SVAT = ''    
    SET @n_startCtn =   0
    SET @n_EndCtn    = 0      
    SET @c_col27 = ''                 --CS01
    SET @c_Col27Ext = 'Ã Ã '            --CS01
    SET @c_Col27split = '/'           --CS01
    SET @n_CNTMSKU = 1                --CS01
    SET @c_getcol27 = ''              --CS01
               
    CREATE TABLE [#Result]  
    (  
     [ID]        [INT] IDENTITY(1, 1) NOT NULL,  
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
      
    CREATE TABLE [#PICK]  
    (  
     [ID]             [INT] IDENTITY(1, 1) NOT NULL,  
     [OrderKey]       [NVARCHAR] (80) NULL,  
     [TTLPICKQTY]     [INT] NULL,  
     [PickZone]       [INT] NULL,  
     [picknotes]      [nvarchar] (100) NULL   
    )      
    
     CREATE TABLE [#MSKU]  
    (  
     [ID]             [INT] IDENTITY(1, 1) NOT NULL,  
     [OrderKey]       [NVARCHAR] (80) NULL,  
     [TTLPICKQTY]     [INT] NULL,  
     [CtnNo]          [INT] NULL,  
     [MSKU]           [nvarchar] (100) NULL   
    )      
    
   IF @b_debug = 1  
   BEGIN  
       PRINT 'start ' +   @c_Sparm4
   END 
   
   SET @c_condition = ''
   
   IF ISNULL(@c_Sparm5,'') <> '' AND ISNULL(@c_Sparm6,'') <> ''
   BEGIN
   	SET @n_startCtn = CONVERT(INT,@c_Sparm5)
   	SET @n_EndCtn  = CONVERT(INT,@c_Sparm6)
   	
   	SET @c_condition = ' AND PD.CartonNo >= @n_startCtn AND PD.CartonNo <= @n_EndCtn'  
   END           
                 
     SET @c_SQLJOIN = +' SELECT DISTINCT ORD.loadkey,ORD.orderkey,ORD.externorderkey,ORD.type,buyerpo,salesman,ORD.facility,ORD.Ordergroup,'--WL01    --8     
                + CHAR(13) +           
                +'STO.Company,STO.SUSR1,STO.SUSR2,(STO.Address1+STO.Address2+STO.Address3),ORD.Notes,'''',ORD.Storerkey,STO.State,'  --16        
                + CHAR(13) +          
                +'STO.City,STO.Zip,STO.Contact1,(STO.Phone1 + ISNULL(STO.Phone2,'''')),OI.Orderinfo08,ORD.Consigneekey,ORD.c_Company,ORD.c_Address1,'+ CHAR(13) +          
                +'ISNULL(ORD.c_Address2,''''),(ISNULL(ORD.C_Address3,'''') + ISNULL(ORD.C_Address4,'''')),'''',ORD.C_State,ORD.C_City,ORD.C_Zip,ORD.C_Contact1,ORD.C_Phone1,'          
                +'ISNULL(ORD.C_Phone2,''''),CASE WHEN STO.VAT=''LEV'' THEN ORD.Notes2 ELSE ORD.M_Company END,ORD.Userdefine01,ORD.Userdefine02,'         
                +'CASE WHEN STO.VAT=''ITX'' THEN ORD.door ELSE  ORD.Userdefine03 END,Packinfo.RefNo,ORD.Userdefine05,' --ORD.PmtTerm,'      
                + CHAR(13) +   
               -- +' CASE WHEN STO.Storerkey = ''ANF'' THEN ORD.DeliveryNote Else ORD.PmtTerm END ,'     
                +'OI.PayableAmount,'
                +'ORD.InvoiceAmount,'''','''','           
                +'ORD.ShipperKey,STO.B_Company,(STO.B_Address1+STO.B_Address2+STO.B_Address3),STO.B_Contact1,STO.B_Phone1,ORD.DeliveryPlace,'''', '  --50       
                +' '''',ORD.IntermodalVehicle,'''',substring(ISNULL(ORD.M_City,'''') + ISNULL(ORD.M_Address1,'''') + ISNULL(ORD.M_Address2,''''),1,80),'
                + ' '''','''',ORD.Priority,ORD.Userdefine10,PD.CartonNo,F.Userdefine11 '        
                + CHAR(13) +            
                + ' FROM ORDERS ORD WITH (NOLOCK) INNER JOIN ORDERDETAIL ORDDET WITH (NOLOCK)  ON ORD.ORDERKEY = ORDDET.ORDERKEY   '       
                + ' INNER JOIN STORER STO WITH (NOLOCK) ON STO.STORERKEY = ORD.STORERKEY '   
                + ' INNER JOIN PACKHEADER PH WITH (NOLOCK) ON PH.OrderKey = ORD.OrderKey'    
                + ' INNER JOIN PACKDETAIL PD WITH (NOLOCK) ON PD.Pickslipno = PH.Pickslipno'   
                + ' LEFT OUTER JOIN PACKINFO (NOLOCK) ON ( PD.PickSlipNo = PACKINFO.PickSlipNo '
					 +'								AND PD.CartonNo = PACKINFO.CartonNo )     '
                + ' INNER JOIN FACILITY F WITH (NOLOCK) ON F.Facility = ORD.Facility ' 
                + ' LEFT JOIN ORDERINFO OI WITH (NOLOCK) ON OI.Orderkey = ORD.Orderkey '          
                + ' WHERE ORD.LoadKey = @c_Sparm1 '        
                + ' AND ORD.OrderKey = CASE WHEN ISNULL(RTRIM(@c_Sparm2),'''') <> '''' THEN @c_Sparm2 ELSE ORD.OrderKey END'        
                + ' AND ORD.ShipperKey = CASE WHEN ISNULL(RTRIM(@c_Sparm3),'''') <> '''' THEN @c_Sparm3 ELSE ORD.ShipperKey END'   
             --   + ' AND PD.QTY = ''1'' '        
              
         
      IF @b_debug = 1  
      BEGIN  
      	 PRINT @c_condition
          PRINT @c_SQLJOIN  
      END               
              
  SET @c_SQL='INSERT INTO #Result (Col01,Col02,Col03,Col04,Col05, Col06,Col07,Col08,Col09'  + CHAR(13) +           
             +',Col10,Col11,Col12,Col13,Col14,Col15,Col16,Col17,Col18,Col19,Col20,Col21,Col22'  + CHAR(13) +           
             +',Col23,Col24,Col25,Col26,Col27,Col28,Col29,Col30,Col31,Col32,Col33,Col34' + CHAR(13) +           
             +',Col35,Col36,Col37,Col38,Col39,Col40,Col41,Col42,Col43,Col44'  + CHAR(13) +           
             +',Col45,Col46,Col47,Col48,Col49,Col50,Col51,Col52,Col53,Col54'+ CHAR(13) +           
             + ',Col55,Col56,Col57,Col58,Col59,Col60) '          
    
   SET @c_SQL = @c_SQL + @c_SQLJOIN  + @c_condition      
     
     SET @c_ExecArguments = N' @c_Sparm1           NVARCHAR(80)'    
                          + ', @c_Sparm2           NVARCHAR(80) '    
                          + ', @c_Sparm3           NVARCHAR(80)'   
                          + ', @n_startCtn         INT'  
                          + ', @n_EndCtn           INT'    
                         
   EXEC sp_ExecuteSql     @c_SQL     
                        , @c_ExecArguments    
                        , @c_Sparm1    
                        , @c_Sparm2    
                        , @c_Sparm3   
                        , @n_startCtn 
                        , @n_EndCtn  
        
  --EXEC sp_executesql @c_SQL          
        
   IF @b_debug = 1  
   BEGIN  
       PRINT @c_SQL  
   END  
  
   IF @b_debug = 1  
   BEGIN  
       SELECT *  
       FROM   #Result(NOLOCK)  
   END       
            
   DECLARE CUR_RowNoLoop CURSOR LOCAL FAST_FORWARD READ_ONLY FOR              
             
   SELECT DISTINCT col02,col38,col59 from #Result          
       
   OPEN CUR_RowNoLoop            
       
   FETCH NEXT FROM CUR_RowNoLoop INTO @c_OrderKey,@c_Udef04,@c_cartonNo         
         
   WHILE @@FETCH_STATUS <> -1            
   BEGIN           
         IF @b_debug='1'        
         BEGIN        
            PRINT @c_OrderKey           
         END        
   --  SELECT @n_SumPICKDETQty = SUM(QTY)            
   --  FROM PICKDETAIL PD (NOLOCK)            
   --   WHERE PD.OrderKey=@c_OrderKey            
  
   IF @c_Sparm4 < '8'  
   BEGIN  
       SELECT @n_SumPICKDETQty = SUM(PDET.QTY),  
              @n_SumUnitPrice = SUM(PD.QTY * ORDDET.Unitprice)  
       --FROM   PICKDETAIL PD(NOLOCK)  
       FROM PACKHEADER PH (NOLOCK)
       JOIN PACKDETAIL PD (NOLOCK) ON PH.PickSlipNo=PD.PickSlipNo
       JOIN ORDERS ORD (NOLOCK) ON ORD.OrderKey = PH.OrderKey
       JOIN PICKDETAIL PDET (NOLOCK) ON PDET.CaseID=PD.LabelNo 
                                      AND PDET.Storerkey=PD.StorerKey
                                      AND PDET.sku=PD.sku
       JOIN ORDERDETAIL ORDDET(NOLOCK)  
                   ON  PDET.OrderKey = ORDDET.OrderKey  
                   AND PDET.sku = ORDDET.sku  
                   AND ORDDET.OrderLineNumber=PDET.OrderLineNumber
       WHERE  PH.OrderKey = @c_OrderKey
       AND PD.CartonNo=CONVERT(INT,@c_cartonNo)  
   END  
   ELSE  
   BEGIN  
       SELECT @n_SumPICKDETQty = SUM(PD.QTY),  
              @n_SumUnitPrice     = SUM(PAD.QTY * ORDDET.Unitprice), 
              @n_cntPickzone      = COUNT(DISTINCT l.pickzone)  
              --@c_picknotes        = PD.notes  
       FROM PACKHEADER PH (NOLOCK)
       JOIN PACKDETAIL PAD (NOLOCK) ON PH.PickSlipNo=PAD.PickSlipNo  
       JOIN PICKDETAIL PD WITH (NOLOCK)  ON PD.PickSlipNo=PH.PickSlipNo
              JOIN ORDERDETAIL ORDDET WITH (NOLOCK)  
                   ON  PD.OrderKey = ORDDET.OrderKey  
                   AND PD.OrderLineNumber = ORDDET.OrderLineNumber  
              JOIN LOC L WITH (NOLOCK)  
                   ON  L.LOC = PD.LOC  
       WHERE  PD.OrderKey = @c_OrderKey 
       AND PAD.CartonNo=CONVERT(INT,@c_cartonNo)   
       --GROUP BY PD.notes  
         
       SELECT TOP 1 @c_picknotes = PD.notes   
        FROM PACKHEADER PH (NOLOCK)
       JOIN PACKDETAIL PAD (NOLOCK) ON PH.PickSlipNo=PAD.PickSlipNo  
       JOIN PICKDETAIL PD WITH (NOLOCK)  ON PD.PickSlipNo=PH.PickSlipNo 
              JOIN ORDERDETAIL ORDDET WITH (NOLOCK)  
                   ON  PD.OrderKey = ORDDET.OrderKey  
                   AND PD.OrderLineNumber = ORDDET.OrderLineNumber  
              JOIN LOC L WITH (NOLOCK)  
                   ON  L.LOC = PD.LOC  
       WHERE  PH.OrderKey = @c_OrderKey
       AND PAD.CartonNo=CONVERT(INT,@c_cartonNo)     
   END  
 
   --SELECT @n_PackInfoWgt = SUM(CAST(PKI.[Weight] as NUMERIC(10,2))) --SUM(CAST(PKI.Weight AS DECIMAL(6,2))) 
   SELECT TOP 1 @c_col56 = CAST((CAST(PKI.[Weight] as NUMERIC(10,2))) as NVARCHAR(30))
   FROM   PACKHeader PH WITH (NOLOCK)  
   JOIN   PACKDETAIL PAD (NOLOCK) ON PH.PickSlipNo=PAD.PickSlipNo  
          JOIN Orders ORD WITH (NOLOCK)  
               ON  ORD.OrderKey = PH.OrderKey  
          JOIN PACKINFO PKI WITH (NOLOCK)  
               ON  PKI.Pickslipno = PH.pickslipno  
   WHERE  PH.OrderKey = @c_OrderKey    
   AND    PKI.CartonNo=CONVERT(INT,@c_cartonNo)   
   
   IF @b_debug='1'        
         BEGIN        
            SELECT @c_col56 '@c_col56'          
         END   
 
   SELECT TOP 1 @c_col35 = CAST(SUM(CAST(PKI.[Cube] as NUMERIC(10,6))) as NVARCHAR(30))  
   FROM   PACKHeader PH WITH (NOLOCK)  
          JOIN Orders ORD WITH (NOLOCK)  
               ON  ORD.OrderKey = PH.OrderKey  
          JOIN PACKINFO PKI WITH (NOLOCK)  
               ON  PKI.Pickslipno = PH.pickslipno  
          JOIN Storer S WITH (NOLOCK) ON S.Storerkey = ORD.Storerkey
   WHERE  PH.OrderKey = @c_OrderKey 
   GROUP BY S.VAT,PKI.[Cube],ORD.Userdefine01 

	 IF @b_debug='1'        
      BEGIN        
         SELECT @c_col35 '@c_col35'          
      END  
   
   SET @c_col39=''
  
   
   SET @n_getcol39   = 0      
   SET @c_getstorerkey = ''     
   SET @c_doctype    = ''       
   SET @c_OHUdef01   = ''   
   SET @c_GetCol53 = ''  
          
   
    SELECT TOP 1 @c_getstorerkey = storerkey
                ,@c_doctype = DocType
                ,@c_OHUdef01=UserDefine01
        FROM   ORDERS WITH (NOLOCK)  
       WHERE  OrderKey = @c_OrderKey  
   
   
   IF @c_getstorerkey = 'ANF' AND @c_doctype = 'DTC' AND @c_OHUdef01='COD'
   BEGIN
   
   SELECT TOP 1 @n_getcol39 = SUM(QTY * ORDDET.Unitprice)+
                                 SUM(CASE WHEN ISNUMERIC(ORDDET.UserDefine05) = 1 THEN CAST(ORDDET.UserDefine05 AS INT) ELSE 0 END) + ORDDET.ExtendedPrice
                               +SUM(ORDDET.Tax01)
                               +sum(CASE WHEN ISNUMERIC(ORDDET.UserDefine06) = 1 THEN CAST(ORDDET.UserDefine06 AS INT) ELSE 0 END) 
       FROM   PICKDETAIL PD(NOLOCK)  
       JOIN ORDERDETAIL ORDDET(NOLOCK)  
       ON  PD.OrderKey = ORDDET.OrderKey  
       AND PD.OrderLineNumber = ORDDET.OrderLineNumber  
       JOIN ORDERS ORD (NOLOCK) ON ORD.OrderKey=ORDDET.OrderKey
       WHERE  PD.OrderKey = @c_OrderKey  
   GROUP BY ORD.Storerkey,ORD.[Type],ORD.UserDefine01,ORD.UserDefine05, ORDDET.ExtendedPrice
   
   SET @c_col39 = CONVERT(NVARCHAR(50),@n_getcol39)
   
   END  
   
   SELECT @c_GetCol53 = CONVERT(NVARCHAR(10),SUM(CAST(PD.RefNo2 AS INT)))
   FROM PACKHEADER PH WITH (NOLOCK)
   JOIN PACKDETAIL PD WITH (NOLOCK) ON PD.PickSlipNo=PH.PickSlipNo
    WHERE PH.OrderKey = @c_OrderKey 
    AND PD.CartonNo = @c_cartonNo
   
    IF @b_debug='1'        
         BEGIN        
            SELECT @c_GetCol53 '@c_GetCol53'          
         END  
         
         /*CS01 Start*/
         SET @n_CNTMSKU = 1
         
         SELECT @n_CNTMSKU = COUNT(1) 
			FROM packdetail pd (NOLOCK)
			JOIN sku s WITH (NOLOCK) ON s.storerkey=pd.StorerKey AND s.sku = pd.sku
			JOIN pickdetail pidet (NOLOCK) ON pidet.caseid = pd.labelno AND pidet.sku=pd.SKU
			WHERE pidet.orderkey=@c_OrderKey 
			AND cartonno=@c_cartonNo
			
			
			INSERT INTO #MSKU (OrderKey, TTLPICKQTY, CtnNo, MSKU)
			SELECT TOP 3 pidet.OrderKey,SUM(pidet.Qty),pd.CartonNo,s.MANUFACTURERSKU
			FROM packdetail pd (NOLOCK)
			JOIN sku s WITH (NOLOCK) ON s.storerkey=pd.StorerKey AND s.sku = pd.sku
			JOIN pickdetail pidet (NOLOCK) ON pidet.caseid = pd.labelno AND pidet.sku=pd.SKU
			WHERE pidet.orderkey=@c_OrderKey 
			AND cartonno=@c_cartonNo
			GROUP BY pidet.OrderKey,pd.CartonNo,s.MANUFACTURERSKU
			ORDER BY s.MANUFACTURERSKU
			
			
			SET @c_col27 = ''
			SET @c_getcol27 = ''              --CS01
			  
   DECLARE CUR_MSKU CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT DISTINCT id,MSKU,MSKU.TTLPICKQTY   
   FROM   #MSKU MSKU   
   WHERE orderkey = @c_OrderKey 
   AND MSKU.CtnNo = @c_cartonNo
  
   OPEN CUR_MSKU   
     
   FETCH NEXT FROM CUR_MSKU INTO @n_id,@c_MSKU,@n_MQTY    
     
   WHILE @@FETCH_STATUS <> -1  
   BEGIN    
   	
   	  IF @n_id < 3  
   	  BEGIN
   	  		IF @n_id = @n_CNTMSKU
   	  		BEGIN
   	  		 SET @c_Col27split = ''
   	  		END
   	  END		
   	  ELSE
   	  BEGIN
   	  	SET @c_Col27split = ''
   	  END	 
   	  
   	  SET @c_getcol27 = @c_MSKU +SPACE(2) + '['  + CONVERT(NVARCHAR(5),@n_MQTY) + ']' + @c_Col27split
   	
   	  SET @c_col27 = @c_col27 + @c_getcol27 --+ @c_Col27split
   	  
   	   IF @b_Debug = '2'    
			BEGIN    
				SELECT @c_getcol27 AS '@c_getcol27' , @c_col27 '@c_col27'
				SELECT *    
				FROM   #MSKU WITH (NOLOCK)    
			END  
   	  
   	  SET @c_getcol27 = ''  
			
   FETCH NEXT FROM CUR_MSKU INTO @n_id,@c_MSKU ,@n_MQTY 
   END      
     
     
        IF @n_CNTMSKU <= 3
   	  BEGIN
   	  	SET @c_Col27Ext = ''
   	  END
   	
   	  SET @c_col27 = @c_col27 + @c_getcol27 + @c_Col27Ext
     
   /*CS01 END*/        
   UPDATE #Result            
   SET Col42 = @n_SumPICKDETQty,   
       COL43 = @n_SumUnitPrice,  
       Col56 = @c_col56,    
       Col35 = @c_Col35,               
       Col39 = CASE WHEN ISNULL(@c_col39,'') <> '' THEN @c_col39 ELSE Col39 END ,  
       col53 = @c_GetCol53,
       col27 = @c_col27      
   WHERE Col02=@c_OrderKey  
   AND col59 = @c_cartonNo       
    
  
  INSERT INTO #PICK (OrderKey,TTLPICKQTY,PickZone,picknotes)      
  VALUES (@c_OrderKey,convert(int,@n_SumPICKDETQty),ISNULL(@n_cntPickzone,0),@c_picknotes)    
  
   
  IF @b_Debug = '1'    
  BEGIN    
    SELECT 'Pick'  
    SELECT *    
    FROM   #PICK WITH (NOLOCK)    
  END    
    
   FETCH NEXT FROM CUR_RowNoLoop INTO @c_OrderKey,@c_Udef04,@c_cartonNo        
    
END -- While             
CLOSE CUR_RowNoLoop            
DEALLOCATE CUR_RowNoLoop          
      
SET @c_ORDAdd = ''   
     
DECLARE CUR_UpdateRec CURSOR LOCAL FAST_FORWARD READ_ONLY FOR              
SELECT DISTINCT col02     
FROM #Result          
    
OPEN CUR_UpdateRec            
    
FETCH NEXT FROM CUR_UpdateRec INTO @c_OrderKey         
      
WHILE @@FETCH_STATUS <> -1            
BEGIN       
   SET @c_ShipperKey = ''    
   SET @c_ORDAdd = ''    
          
   SELECT @c_ORDAdd = RTRIM(ORD.C_State) + ' ' + RTRIM(ORD.C_City) + ' ' + RTRIM(ORD.C_Address1)   
         ,@c_city = RTRIM(ORD.C_City)                      
         ,@c_State = RTRIM(ORD.C_State)                      
         ,@c_Address1 = RTRIM(ORD.C_Address1)              
         ,@c_storerkey = ORD.Storerkey
         ,@c_door      = ORD.Door
         ,@c_deliveryNote = ORD.DeliveryNote
         ,@c_getshipperkey = ORD.ShipperKey
   FROM ORDERS ORD WITH (NOLOCK)      
   WHERE ORD.Orderkey =   @c_OrderKey    


  
    
   IF @b_debug = '1'      
   BEGIN       
      PRINT ' ORD address combine : ' + @c_ORDAdd + ' with orderkey : ' + @c_OrderKey      
   END    
      
   SET @c_CLong = ''    
     
   SELECT @c_consigneeFor = ISNULL(consigneeFor,'')  
   FROM Orders Ord WITH (NOLOCK)  
   JOIN Storer S WITH (NOLOCK) ON S.storerkey=Ord.Shipperkey   
   WHERE Ord.Orderkey=@c_OrderKey  
  
   IF @b_debug='1'  
    BEGIN  
      Print ' consigneeFor : ' + @c_consigneeFor  
    END  
    
     
   IF  @c_consigneeFor = 'A'   
    BEGIN  

          SELECT TOP 1 @c_cnotes = c.notes,
                        @c_short = C.short
          FROM Codelkup C WITH (NOLOCK)   
          WHERE C.short =  @c_getshipperkey      
           AND C.Listname='COURIERMAP'     
           AND C.UDF01='ELABEL'   


          SELECT TOP 1    
            @c_CLong = C.Long      
         FROM Codelkup C WITH (NOLOCK)      
         WHERE C.short =  @c_getshipperkey      
         AND C.Listname='COURIERMAP'     
         AND C.UDF01='ELABEL'         
         AND c.notes like N'%' + @c_City + '%'  
  
        IF @b_debug='1'  
          BEGIN  
            Print ' c_long : ' + @c_CLong  
          END  
  
        IF ISNULL(@c_CLong,'') = ''  
        BEGIN  
        SELECT TOP 1    
            --@c_notes = C.notes     
              @c_City = Ord.c_city  
         FROM ORDERS ORD WITH (NOLOCK) --ON ORD.ShipperKey = C.Short        
         WHERE ORD.Orderkey =  @c_OrderKey  
         AND  ORD.ShipperKey = @c_short                        
  
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
  
   SET @c_notes2 = ''   

  SELECT @c_SVAT = VAT
  FROM STORER WITH (NOLOCK)
  WHERE Storerkey=@c_storerkey


  IF @c_SVAT IN ('ITX','NIKE') AND @c_Door = '99' 
  BEGIN
      SET @c_notes2= @c_deliveryNote  
  END
  ELSE
  BEGIN
   
  SELECT TOP 1 @c_notes2 = C.Notes2         
   FROM   Codelkup C WITH (NOLOCK)   
     WHERE C.Short = @c_GetShipperkey               
          AND C.Storerkey = @c_storerkey           
          AND C.Listname = 'WSCourier'

  END

   SET @c_UDF01 = ''   
   SELECT TOP 1   
          @c_UDF01 = C.UDF01  
   FROM   Codelkup C WITH (NOLOCK)    
   WHERE C.Short = @c_GetShipperkey              
          AND C.Storerkey = @c_storerkey            
          AND C.Listname = 'WSCourier'   
 
  
    SET @c_GetCol55 = ''  
  
    SELECT TOP 1 @c_GetCol55 = C.Long  
    FROM Codelkup C WITH (NOLOCK)   
    WHERE C.listname='ELCOL55'   
    AND c.Storerkey = @c_Storerkey           
  
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
  
    SET @c_ExecStatements = N'SELECT @c_col55 =' + @c_GetCol55 + ' from orders (nolock) where orderkey=@c_OrderKey '  
  
    SET @c_ExecArguments = N'@c_GetCol55    NVARCHAR(80) '  
                          +',@c_OrderKey   NVARCHAR(30)'  
                          +',@c_col55      NVARCHAR(20) OUTPUT'  
  
     EXEC sp_ExecuteSql @c_ExecStatements   
                      , @c_ExecArguments  
                      , @c_GetCol55       
                      , @c_OrderKey  
                      , @c_col55 OUTPUT  
  
  
    IF @b_debug = '1'  
        BEGIN  
          PRINT ' Col55 : ' + @c_Col55   
        END    
  
   IF @b_debug = '1'  
   BEGIN  
       PRINT ' codelkup long : ' + @c_CLong + 'and notes2 : ' + @c_notes2 +   
       ' with orderkey : ' + @c_OrderKey  
   END     
      
   UPDATE #Result WITH (ROWLOCK)  
   SET    Col50     = @c_CLong,  
          Col51     = @c_notes2,   
          Col14     = @c_UDF01,   
          Col55     = @c_Col55    
   WHERE  Col02     = @c_OrderKey       
      
   FETCH NEXT FROM CUR_UpdateRec INTO @c_OrderKey         
    
END -- While          
    --        
CLOSE CUR_UpdateRec            
DEALLOCATE CUR_UpdateRec        
           
   IF ISNULL(@c_Sparm4 ,0) <> 0   
   BEGIN    
       IF @c_Sparm4 = '1'  
       BEGIN  
           SELECT R.*  
           FROM   #Result R WITH (NOLOCK)   
           INNER  JOIN #PICK P WITH (NOLOCK)  
                       ON  P.Orderkey = R.Col02  
           WHERE  ISNULL(Col38, '') <> ''  
           AND P.TTLPICKQTY = 1  
           ORDER BY col59,  
                    --col60,  
                    col02  
       END    
       ELSE   
    
       IF @c_Sparm4 > '1' AND @c_Sparm4 < '8'    
       BEGIN    
           SELECT R.*     
           FROM   #Result R WITH (NOLOCK)    
           INNER JOIN #PICK P WITH (NOLOCK)   
                      ON  P.Orderkey = R.Col02    
           WHERE  ISNULL(Col38 ,'') <> ''   
           AND    P.TTLPICKQTY > 1    
           ORDER BY col02    
       END    
       ELSE 

       IF @c_Sparm4 = '8' 
       BEGIN  
         SELECT R.*     
           FROM   #Result R WITH (NOLOCK)    
           INNER JOIN #PICK P WITH (NOLOCK)   
                      ON  P.Orderkey = R.Col02    
           WHERE  ISNULL(Col38 ,'') <> ''    
           AND    P.TTLPICKQTY > 1 AND P.PickZone>1  
           ORDER BY --P.PickZone,           
                    --P.picknotes,          
                    col02  
                    --col60 
       END
       ELSE

       BEGIN  
      
       SELECT R.*     
           FROM   #Result R WITH (NOLOCK)    
           INNER JOIN #PICK P WITH (NOLOCK)   
                      ON  P.Orderkey = R.Col02    
           WHERE  ISNULL(Col38 ,'') <> ''     
           AND    P.TTLPICKQTY > 1 AND P.PickZone=1    
           ORDER BY P.PickZone,         
                    P.picknotes,          
                    col02,  
                    col60    
       END  
       
   END    
   ELSE    
   BEGIN  
    SELECT *  
    FROM   #Result WITH (NOLOCK)  
    WHERE  ISNULL(Col38, '') <> ''     
      --AND P.PickZone=1  
    ORDER BY  
           Col02  
   END                   
                 
EXIT_SP:    
  
   SET @d_Trace_EndTime = GETDATE()  
   SET @c_UserName = SUSER_SNAME()  
     
   EXEC isp_InsertTraceInfo   
      @c_TraceCode = 'BARTENDER',  
      @c_TraceName = 'isp_BT_Bartender_Shipper_Label_5',  
      @c_starttime = @d_Trace_StartTime,  
      @c_endtime = @d_Trace_EndTime,  
      @c_step1 = @c_UserName,  
      @c_step2 = '',  
      @c_step3 = '',  
      @c_step4 = '',  
      @c_step5 = '',  
      @c_col1 = @c_Sparm1,   
      @c_col2 = @c_Sparm2,  
      @c_col3 = @c_Sparm3,  
      @c_col4 = @c_Sparm4,  
      @c_col5 = @c_Sparm5,  
      @b_Success = 1,  
      @n_Err = 0,  
      @c_ErrMsg = ''              
                                    
END -- procedure   



GO