SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Stored Procedure: isp_Ecom_DeliveryOrder                             */    
/* Creation Date:                                                       */    
/* Copyright: IDS                                                       */    
/* Written by: GTGoh (Duplicate from isp_DeliveryOrder03)               */    
/*                                                                      */    
/* Purpose: E-Comm Order Despatch Manifest                              */    
/*                                                                      */    
/* Called By: r_dw_ecom_despatch_manifest  SOS#190630                   */     
/*                                                                      */    
/* Parameters: (Input)  @c_StorerKey = StorerKey                        */    
/*                      @c_OrderKey  = OrderKey                         */    
/*                                                                      */    
/* PVCS Version: 1.0                                                    */    
/*                                                                      */    
/* Version: 5.4                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date         Author   Ver. Purposes                                  */    
/* 18-10-2010   James    1.1  Add externorderkey as search criteria     */
/*                            (james01)                                 */
/* 21-10-2010   James    1.2  Only pick and pack match then can print   */
/*                            manifest (james02)                        */
/* 25-10-2010   James    1.3  No print if pick n pack not match(james02)*/  
/* 09-02-2011   NJOW01   1.4  Add orders.notes2                         */
/* 04-03-2011   James    1.5  Extend orders.notes2 (james03)            */
/* 09-03-2011   James    1.6  If incoterm = 'CC' then card holder name  */
/*                            will be from m_contact1 (james04)         */
/* 24-05-2011   NJOW02   1.7  216248 - Change cardholder name mapping   */
/*                            from C_contact1 to B_contact1 (ecom ord)  */
/************************************************************************/    
CREATE PROCEDURE [dbo].[isp_Ecom_DeliveryOrder]  
        @c_StorerKey       NVARCHAR(15),     
        @c_OrderKey        NVARCHAR(10),    
        @c_ExternOrderKey  NVARCHAR(30) = ''   
AS    
BEGIN    
   SET NOCOUNT ON    
   SET ANSI_DEFAULTS OFF      
   SET QUOTED_IDENTIFIER OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
    
DECLARE  @c_UserDefine02    NVARCHAR(20),    
         @c_Tender          NVARCHAR(300),    
         @c_TenderCode      NVARCHAR(250),    
         @n_Count           INT,    
         @c_Asterisks       NVARCHAR(20),  
         @c_LabelType       NVARCHAR(10),   
         @c_IncoTerm        NVARCHAR(10),   
         @c_susr1           NVARCHAR(20),   
         @c_susr2           NVARCHAR(20),   
         @c_m_vat           NVARCHAR(18),   
         @b_success         int,           
         @n_err             int,           
         @c_errmsg          NVARCHAR(225),     
         @c_EUCountry       NVARCHAR(10),   
         @c_cdigit          NVARCHAR(1),       
         @c_ExtOrderKey     NVARCHAR(30),       
         @c_C_contact1      NVARCHAR(30),    
         @c_C_Address1      NVARCHAR(45),  
         @c_C_Address2      NVARCHAR(45),  
         @c_C_Address3      NVARCHAR(45),  
         @c_C_Address4      NVARCHAR(45),  
         @c_C_Country       NVARCHAR(30),  
         @c_C_Zip           NVARCHAR(18),  
         @c_Style           NVARCHAR(20),  
         @c_DESCR           NVARCHAR(60),  
         @c_Color           NVARCHAR(10),  
         @c_Notes           NVARCHAR(20),  
         @c_Size            NVARCHAR( 5),  
         @d_UnitPrice       DECIMAL(10, 2),    
         @c_OrdersNotes     NVARCHAR(250),    
         @n_Qty             INT,  
         @d_UserDefine04    DECIMAL(10, 2),   
         @d_UserDefine10    DECIMAL(10, 2),  
         @d_UserDefine05    DECIMAL(10, 2),  
         @n_Page      INT,  
         @c_ExecStatements  NVARCHAR(4000),  
         @c_Detail          NVARCHAR(100),  
         @d_TotalBeforeDisc DECIMAL(10,2),
         @n_Tot_Pick        INT,    -- (james02)
         @n_Tot_Pack        INT,    -- (james02)
         @n_RemainingQty    INT, 
         @c_OrderLineNumber INT, 
         @n_QtyPicked       INT,
         @c_OrdersNotes2    NVARCHAR(26) --NJOW01  

   DECLARE @c_DropID   NVARCHAR(18),  
           @c_RefNo    NVARCHAR(20),  
           @d_EditDate DATETIME  
 
   CREATE TABLE #RESULT    
   (C_contact1      NVARCHAR(30)      NULL,    
    C_Address1      NVARCHAR(45)      NULL,    
    C_Address2      NVARCHAR(45)      NULL,    
    C_Address3      NVARCHAR(45)      NULL,    
    C_Address4      NVARCHAR(45)      NULL,    
    C_Country       NVARCHAR(30)      NULL,    
    C_Zip           NVARCHAR(18)      NULL,    
    EditDate        DATETIME         NULL,    
    ExternOrderKey  NVARCHAR(30)      NULL,    
    RefNo           NVARCHAR(20)      NULL,    
    Tender          NVARCHAR(300)     NULL,    
    DropID          NVARCHAR(18)      NULL,    
    OrdersNotes     NVARCHAR(250)     NULL,    
    UserDefine04    DECIMAL(10, 2)   NULL,    
    UserDefine10    DECIMAL(10, 2)   NULL,    
    UserDefine05    DECIMAL(10, 2)   NULL,  
    Detail1         NVARCHAR(100)     DEFAULT (''),     
    Detail2         NVARCHAR(100)     DEFAULT (''),  
    Detail3         NVARCHAR(100)     DEFAULT (''),  
    Detail4         NVARCHAR(100)     DEFAULT (''),  
    Detail5         NVARCHAR(100)     DEFAULT (''),  
    Detail6         NVARCHAR(100)     DEFAULT (''),  
    Detail7         NVARCHAR(100)     DEFAULT (''),  
    Detail8         NVARCHAR(100)     DEFAULT (''),  
    Detail9         NVARCHAR(100)     DEFAULT (''),   
    Detail10        NVARCHAR(100)     DEFAULT (''),  
    Detail11        NVARCHAR(100)     DEFAULT (''),  
    Detail12        NVARCHAR(100)     DEFAULT (''),  
    Detail13        NVARCHAR(100)     DEFAULT (''),  
    Detail14        NVARCHAR(100)     DEFAULT (''),  
    Detail15        NVARCHAR(100)     DEFAULT (''),  
    Detail16        NVARCHAR(100)     DEFAULT (''),  
    Detail17        NVARCHAR(100)     DEFAULT (''),  
    Detail18        NVARCHAR(100)     DEFAULT (''),  
    Detail19        NVARCHAR(100)     DEFAULT (''),  
    Detail20        NVARCHAR(100)     DEFAULT (''),  
    PageCounter     INT              NULL,  
    TotalBeforeDisc DECIMAL(10, 2)   NULL,
    OrdersNotes2    NVARCHAR(26)      NULL)   --NJOW01/(james03)   
      
   SELECT @c_UserDefine02 = ''    
   SELECT @c_TenderCode   = ''    
   SELECT @n_Count        = 0    

   --james01 Start
   IF RTRIM(ISNULL(@c_OrderKey,'')) = '' AND RTRIM(ISNULL(@c_ExternOrderKey,'')) <> ''
   BEGIN    
      SELECT @c_OrderKey = OrderKey  
      FROM Orders WITH (NOLOCK) 
      WHERE StorerKey = @c_StorerKey
         AND ExternOrderKey = @c_ExternOrderKey
         AND Status <> 'CANC' 
   END
   --james01 End

   SELECT TOP 1  
        @c_DropID = PD.DropID  
   FROM PackDetail PD WITH (NOLOCK)  
   JOIN PackHeader PH WITH (NOLOCK) ON (PD.PickSlipNo = PH.PickSlipNo)      
   WHERE PD.StorerKey = @c_StorerKey    
   AND   PH.Orderkey = @c_OrderKey  
   ORDER BY PD.EditDate  
         
   -- james02 start
   SELECT @n_Tot_Pick = ISNULL(SUM(QTY), 0) 
   FROM PICKDETAIL PD WITH (NOLOCK) 
   WHERE StorerKey = @c_StorerKey
      AND OrderKey = @c_OrderKey
      AND Status >= '5'

   SELECT @n_Tot_Pack = ISNULL(SUM(QTY), 0) 
   FROM PACKDETAIL PD WITH (NOLOCK)
   JOIN PACKHEADER PH WITH (NOLOCK) ON (PD.PickSlipNo = PH.PickSlipNo)
   WHERE PH.StorerKey = @c_StorerKey
      AND PH.OrderKey = @c_OrderKey

   IF @n_Tot_Pick <> @n_Tot_Pack
      GOTO Quit
   -- james02 end

   SELECT @c_UserDefine02 = ISNULL(RTRIM(UserDefine02), '')  
   FROM ORDERS WITH (NOLOCK)       
   WHERE OrderKey = @c_OrderKey    
    
   SELECT @c_TenderCode = ISNULL(RTRIM(Code), '')     
   FROM CodeLKup WITH (NOLOCK)    
   WHERE LISTNAME = 'TENDER'    
   AND Code = ISNULL(RTRIM(SUBSTRING(@c_UserDefine02,7,20)), '')    
    
   IF ISNUMERIC(ISNULL(RTRIM(SUBSTRING(@c_UserDefine02,5,2)), 0)) = 1    
   BEGIN    
      SELECT @n_Count = ISNULL(RTRIM(SUBSTRING(@c_UserDefine02,5,2)), 0)    
      WHILE @n_Count > 0    
      BEGIN    
         SELECT @n_Count = @n_Count-1    
         SELECT @c_Asterisks = @c_Asterisks + '*'    
      END    
   END    
    
   SELECT @c_Tender = @c_TenderCode + ' ' + @c_Asterisks + ISNULL(RTRIM(SUBSTRING(@c_UserDefine02,1,4)), '')    
    
   SELECT 
         CASE WHEN ISNULL(ORDERS.Incoterm, '') = 'CC' 
              THEN ORDERS.M_Contact1 
              ELSE ORDERS.B_contact1 --NJOW02
              END AS C_contact1, -- (james04)         
         ORDERS.C_Address1,       
         ORDERS.C_Address2,       
         ORDERS.C_Address3,       
         ORDERS.C_Address4,       
         ORDERS.C_Country,     
         ORDERS.C_Zip,     
         MIN(ORDERDETAIL.EditDate) AS EditDate,       
         ORDERS.ExternOrderKey,       
         SPACE(20) AS RefNo,       
         @c_Tender AS Tender,       
         '' AS DropID, 
         SKU.Style,       
         SKU.DESCR,       
         SKU.Color,       
         ORDERDETAIL.UserDefine01 AS Notes,            
         SKU.Size,     
         ORDERDETAIL.UnitPrice,    
     CAST(ORDERS.Notes AS NVARCHAR(250)) AS OrdersNotes,      
     ORDERDETAIL.EnteredQTY AS Qty,        
     CASE WHEN ISNUMERIC(ORDERS.UserDefine04) = 1     
              THEN ORDERS.UserDefine04    
         ELSE '0.00' END AS UserDefine04,      
     CASE WHEN ISNUMERIC(ORDERS.UserDefine10) = 1     
              THEN ORDERS.UserDefine10    
         ELSE '0.00' END AS UserDefine10,      
     CASE WHEN ISNUMERIC(ORDERS.UserDefine05) = 1     
              THEN ORDERS.UserDefine05    
         ELSE '0.00' END AS UserDefine05,    
         ORDERDETAIL.OrderLineNumber,
     LEFT(ISNULL(CAST(ORDERS.Notes2 AS NVARCHAR(250)),''),26) AS OrdersNotes2 --NJOW01/(james03)
   INTO #ORDER   
   FROM ORDERS WITH (NOLOCK)       
   JOIN ORDERDETAIL WITH (NOLOCK) ON (ORDERS.OrderKey = ORDERDETAIL.OrderKey)      
   JOIN SKU WITH (NOLOCK)         ON (ORDERDETAIL.StorerKey = SKU.StorerKey     
                                  AND ORDERDETAIL.Sku = SKU.Sku)    
   WHERE ORDERS.StorerKey = @c_StorerKey  -- (Vicky02)  
   AND ORDERS.OrderKey = @c_OrderKey      -- (Vicky02)  
   GROUP BY ORDERS.C_contact1,         
            ORDERS.C_Address1,       
            ORDERS.C_Address2,       
            ORDERS.C_Address3,       
            ORDERS.C_Address4,       
            ORDERS.C_Country,     
            ORDERS.C_Zip,      
            ORDERS.ExternOrderKey,       
            ORDERS.UserDefine02,       
            SKU.Style,       
            SKU.DESCR,       
            SKU.Color,       
            ORDERDETAIL.UserDefine01,         
            SKU.Size,       
            ORDERDETAIL.UnitPrice,    
          	CAST(ORDERS.Notes AS NVARCHAR(250)),       
          	CASE WHEN ISNUMERIC(ORDERS.UserDefine04) = 1     
                 THEN ORDERS.UserDefine04    
            ELSE '0.00' END,      
          	CASE WHEN ISNUMERIC(ORDERS.UserDefine10) = 1     
                 THEN ORDERS.UserDefine10    
            ELSE '0.00' END,      
          	CASE WHEN ISNUMERIC(ORDERS.UserDefine05) = 1     
                 THEN ORDERS.UserDefine05    
            ELSE '0.00' END,    
      		ORDERDETAIL.OrderLineNumber, --, PICKDETAIL.STATUS  
          	ORDERDETAIL.EnteredQTY, 
          	LEFT(ISNULL(CAST(ORDERS.Notes2 AS NVARCHAR(250)),''),26), --NJOW01/(james03)
            ORDERS.IncoTerm, 
            CASE WHEN ISNULL(ORDERS.Incoterm, '') = 'CC' 
              THEN ORDERS.M_Contact1 
              ELSE ORDERS.B_contact1 --NJOW02
              END 
   ORDER BY ORDERDETAIL.OrderLineNumber
     
     
      -- (KHLim01)  
      SELECT @c_IncoTerm = ISNULL(RTRIM(IncoTerm),'')    
            ,@c_ExtOrderKey  = ExternOrderKey        -- (KHLim02)  
      FROM  ORDERS WITH (NOLOCK)    
      WHERE Orderkey = @c_OrderKey
          
      -- HDN LABEL  
      IF EXISTS (SELECT 1 FROM dbo.Codelkup WITH (NOLOCK) WHERE Listname = 'HDNTERMS' AND Code = @c_IncoTerm)    
      BEGIN    
         SET @c_LabelType = 'HDNLABEL'    
      END    
      ELSE    
      BEGIN    
         --DPD LABEL  
         IF EXISTS (SELECT 1 FROM RDT.rdtReport WITH (NOLOCK)   
                    WHERE StorerKey = @c_StorerKey AND ReportType = 'DPDLABEL')    
         BEGIN    
            SET @c_LabelType = 'DUMMYLABEL' -- Dummy DPD LABEL  
         END  
         ELSE  
         BEGIN  
            SET @c_EUCountry = 'N'    
            SELECT TOP 1 @c_EUCountry = ISNULL(RTRIM(EUCountry),'N')     
            FROM dbo.REPDPDCNT REPDPDCNT WITH (NOLOCK)  
            JOIN dbo.ORDERS ORDERS WITH (NOLOCK) ON (ORDERS.CountryDestination = REPDPDCNT.IsoCode)    
            WHERE ORDERS.Orderkey = @c_OrderKey    
       
            IF @c_EUCountry = 'N'    
            BEGIN    
               SET @c_LabelType = 'NDPDLABEL' -- National DPD LABEL  
            END    
            ELSE    
            BEGIN    
               SET @c_LabelType = 'EDPDLABEL' -- Europe DPD LABEL  
            END  
         END  
      END    
  
      IF @c_LabelType = 'DUMMYLABEL' -- (KHLim01)  
      BEGIN  
         SET @c_RefNo = @c_ExtOrderKey -- (KHLim02)  
      END  
      ELSE IF @c_LabelType = 'HDNLABEL' -- (KHLim01)  
      BEGIN  
         SELECT TOP 1 @c_RefNo = PIF.RefNo, -- (Vicky02)  
                      @d_EditDate = PD.EditDate
         FROM PackDetail PD WITH (NOLOCK)  
         JOIN PackHeader PH WITH (NOLOCK) ON (PD.PickSlipNo = PH.PickSlipNo)     
         JOIN PackInfo   PIF WITH (NOLOCK) ON (PIF.PickSlipNo = PD.PickSlipNo)  
         WHERE PD.StorerKey = @c_StorerKey    
         --AND   PD.DropID = @c_DropID             
         AND   PH.Orderkey = @c_OrderKey  
         AND   ISNULL(RTRIM(PIF.RefNo), '') <> ''-- (Vicky02)  
         ORDER BY PD.EditDate  
      END  
      ELSE -- (KHLim01)  
      BEGIN  
         SELECT @c_susr1    = RTRIM(ISNULL(STORER.SUSR1,'')),  
                @c_susr2    = RTRIM(ISNULL(STORER.SUSR2,''))  
         FROM STORER WITH (NOLOCK) WHERE STORER.StorerKey = 'IDS'  
  
         SELECT @c_m_vat = RTRIM(ISNULL(ORDERS.M_Vat,''))  
         FROM ORDERS WITH (NOLOCK)  
         WHERE ORDERS.OrderKey = @c_OrderKey   
         AND ORDERS.StorerKey = @c_StorerKey   
           
         IF @c_m_vat = ''   
         BEGIN  
            EXECUTE nspg_GetKey  
               'PARCELNO',   
               6,  
               @c_m_vat    OUTPUT,  
               @b_success  OUTPUT,  
               @n_err      OUTPUT,  
               @c_errmsg   OUTPUT  
                 
            IF @b_success <> 1  
            BEGIN   
               SET @n_err = 60001  
               SET @c_errmsg = 'FAIL To Generate Parcel Number. isp_Ecom_DeliveryOrder'  
               --GOTO QUIT  
            END   
         END  
         IF @c_LabelType = 'NDPDLABEL'  
         BEGIN  
            SET @c_RefNo = RTRIM(@c_susr1) + RTRIM(@c_susr2) + RTRIM(@c_m_vat)  
         END  
         ELSE           -- EDPDLABEL  
         BEGIN  
            SET @c_RefNo = CAST(@c_susr1 AS NVARCHAR(4)) + CAST(@c_susr2 AS NVARCHAR(4)) + RTRIM(@c_m_vat)  
         END  
         EXEC isp_CheckDigitsISO7064  
            @c_RefNo,  
            @b_success OUTPUT,  
            @c_cdigit  OUTPUT  
           
         IF @b_success <> 1  
         BEGIN   
            SET @n_err = 60002  
            SET @c_errmsg = 'FAIL To Check Digit for Parcel Number:' + @c_RefNo + ' isp_Ecom_DeliveryOrder'  
            --GOTO QUIT  
         END   
         SET @c_RefNo = RTRIM(@c_RefNo) + @c_cdigit  
      END  
  
      UPDATE #ORDER  
         SET RefNo = ISNULL(RTRIM(@c_RefNo), '')  
        
   SET @n_Count = 0  
   SET @n_Page  = 0  
   SET @d_TotalBeforeDisc = 0  
     
   DECLARE CUR_ARRAY CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT C_contact1,   C_Address1,    C_Address2,  
         C_Address3,    C_Address4,    C_Country,  
         C_Zip,         EditDate,      ExternOrderKey,  
         RefNo,         Tender,         
         Style,         DESCR,         Color,  
         Notes,         Size,          UnitPrice,  
         OrdersNotes,   Qty,           UserDefine04,  
         UserDefine10,  UserDefine05,  OrderLineNumber,
         OrdersNotes2    
   FROM   #ORDER   
   OPEN CUR_ARRAY   
     
   FETCH NEXT FROM CUR_ARRAY INTO @c_C_contact1,   @c_C_Address1,    @c_C_Address2,  
                                 @c_C_Address3,    @c_C_Address4,    @c_C_Country, 
                                 @c_C_Zip,         @d_EditDate,      @c_ExternOrderKey,  
                                 @c_RefNo,         @c_Tender,         
                                 @c_Style,         @c_DESCR,         @c_Color,  
                                 @c_Notes,         @c_Size,          @d_UnitPrice,  
                                 @c_OrdersNotes,   @n_Qty,           @d_UserDefine04,  
                                 @d_UserDefine10,  @d_UserDefine05,  @c_OrderLineNumber,
                                 @c_OrdersNotes2    
   WHILE @@FETCH_STATUS <> -1  
   BEGIN   
      
      SET @n_RemainingQty = @n_Qty
      
      SET @n_QtyPicked = 0 
      SELECT @n_QtyPicked = SUM(QTY) 
      FROM   PICKDETAIL WITH (NOLOCK) 
      WHERE  OrderKey = @c_OrderKey 
      AND    OrderLineNumber = @c_OrderLineNumber
      AND    STATUS >= 5
        
      WHILE @n_RemainingQty > 0 
      BEGIN
         SET @n_Count = @n_Count + 1  
         SET @d_TotalBeforeDisc = @d_TotalBeforeDisc + @d_UnitPrice -- shong01  
           
         SET @c_Detail = LEFT(ISNULL(RTRIM(@c_Style), '') + SPACE(5),5) +   
                     LEFT(ISNULL(RTRIM(@c_DESCR), '') + SPACE(20),20) +   
                     LEFT(ISNULL(RTRIM(@c_Color), '') + SPACE(10),10) +   
                     LEFT(ISNULL(RTRIM(CASE WHEN @n_QtyPicked > 0 THEN @c_Notes ELSE 'Out Of Stock *' END), '') + SPACE(35),35) +   
                     LEFT(ISNULL(RTRIM(@c_Size), '') + SPACE(5),5) +   
                     LEFT(ISNULL(RTRIM(CAST(CASE WHEN @n_QtyPicked > 0 THEN 1 ELSE 0 END AS NVARCHAR(3))), '') + SPACE(3),3) +   
             LEFT(ISNULL(RTRIM(CAST(@d_UnitPrice AS NVARCHAR(6))), '') + SPACE(6),6)  
               
         IF @n_Count = 1  
         BEGIN   
            SET @n_Page = @n_Page + 1     
            INSERT INTO #RESULT  
            (C_contact1, C_Address1, C_Address2, C_Address3, C_Address4, C_Country,  
             C_Zip, EditDate, ExternOrderKey, RefNo, Tender, DropID, OrdersNotes,   
             UserDefine04, UserDefine10, UserDefine05, Detail1, PageCounter, TotalBeforeDisc, OrdersNotes2)  
            VALUES (  @c_C_contact1, @c_C_Address1, @c_C_Address2, @c_C_Address3, @c_C_Address4, @c_C_Country,  
                      @c_C_Zip, @d_EditDate, @c_ExternOrderKey, @c_RefNo, @c_Tender, @c_DropID, @c_OrdersNotes,   
                      @d_UserDefine04, @d_UserDefine10, @d_UserDefine05,  
                      @c_Detail, @n_Page, @d_UnitPrice, @c_OrdersNotes2 )  
         END  
         ELSE  
         BEGIN  
            SET @c_ExecStatements = '' 
            
            SET @c_ExecStatements = N'UPDATE #RESULT SET Detail' + CAST(@n_Count AS VARCHAR) + '= N''' 
                                + REPLACE(@c_Detail, "'", "''") + ''' '  
                                + 'WHERE PageCounter = ' + CAST(@n_Page AS VARCHAR)  
     
            EXEC (@c_ExecStatements )  
           
         END  
         IF @n_QtyPicked > 0 
            SET @n_QtyPicked = @n_QtyPicked - 1
            
         SET @n_RemainingQty = @n_RemainingQty - 1  
         IF @n_Count = 20 SET @n_Count = 0
           
      END -- WHILE @n_RemainingQty > 0
           
      FETCH NEXT FROM CUR_ARRAY INTO 
                              @c_C_contact1,   @c_C_Address1,    @c_C_Address2,  
                              @c_C_Address3,    @c_C_Address4,    @c_C_Country,  
                              @c_C_Zip,         @d_EditDate,      @c_ExternOrderKey,  
                              @c_RefNo,         @c_Tender,          
                              @c_Style,         @c_DESCR,         @c_Color,  
                              @c_Notes,         @c_Size,          @d_UnitPrice,  
                              @c_OrdersNotes,   @n_Qty,           @d_UserDefine04,  
                              @d_UserDefine10,  @d_UserDefine05,  @c_OrderLineNumber,
                              @c_OrdersNotes2    
   END   
    
   SET @c_ExecStatements = ''  
   SET @c_ExecStatements = N'UPDATE #RESULT SET TotalBeforeDisc = ' + CAST(@d_TotalBeforeDisc AS VARCHAR)  
  
   EXEC (@c_ExecStatements )  

   Quit:
   
   SELECT * FROM #RESULT (NOLOCK)  
   IF OBJECT_ID('tempdb..#ORDER') IS NOT NULL  
      DROP TABLE #ORDER   

   IF OBJECT_ID('tempdb..#RESULT') IS NOT NULL  
      DROP TABLE #RESULT      
END 

GO