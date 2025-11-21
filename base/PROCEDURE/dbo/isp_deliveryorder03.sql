SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Procedure: isp_DeliveryOrder03                                */  
/* Creation Date:                                                       */  
/* Copyright: IDS                                                       */  
/* Written by: Vanessa                                                  */  
/*                                                                      */  
/* Purpose: E-Comm Order Despatch Manifest                              */  
/*                                                                      */  
/* Called By: r_dw_delivery_order_03  SOS#172886                        */   
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
/* 27-Jul-2010  Vicky    1.1  Fix Duplicate RefNo (Vicky01)             */
/* 28-Jul-2010  Vicky    1.2  Orderline which is not allocated should   */
/*                            show in rpt as out of stock (Vicky02)     */
/* 05-Aug-2010  KHLim    1.3  check DPDLabel or HDNlABEL   (KHLim01)    */
/* 05-Aug-2010  KHLim    1.4  show ExternOrderKey for DPD dummy(KHLim02)*/
/* 2010-09-22   James    1.5  Change DPD country field mapping (james01)*/
/************************************************************************/  
CREATE PROCEDURE [dbo].[isp_DeliveryOrder03]
        @c_StorerKey NVARCHAR(15),   
        @c_OrderKey  NVARCHAR(10)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_DEFAULTS OFF    
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @c_UserDefine02    NVARCHAR(20),  
           @c_Tender          NVARCHAR(300),  
           @c_TenderCode      NVARCHAR(250),  
           @n_Count           INT,  
           @c_Asterisks       NVARCHAR(20),
           @cLabelType        NVARCHAR(10), -- (KHLim01)
           @cIncoTerm         NVARCHAR(10), -- (KHLim01)
           @c_susr1           NVARCHAR(20), -- (KHLim01) 
           @c_susr2           NVARCHAR(20), -- (KHLim01)
           @c_m_vat           NVARCHAR(18), -- (KHLim01) to store parcel number 
           @b_success         int,         -- (KHLim01)
           @n_err             int,         -- (KHLim01)
           @c_errmsg          NVARCHAR(225),   -- (KHLim01)
           @cEUCountry        NVARCHAR(10), -- (KHLim01)
           @c_cdigit          NVARCHAR(1),     -- (KHLim01)
           @c_ExtOrderKey     NVARCHAR(30)     -- (KHLim02)

   CREATE TABLE #ORDER  
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
    Style           NVARCHAR(20)      NULL,  
    DESCR           NVARCHAR(60)      NULL,  
    Color           NVARCHAR(10)      NULL,  
    Notes           NVARCHAR(20)      NULL,  
    Size         NVARCHAR(5)       NULL,  
    UnitPrice       DECIMAL(10, 2)   NULL,  
    OrdersNotes     NVARCHAR(250)     NULL,  
    Qty             INT              NULL,   
    UserDefine04    DECIMAL(10, 2)   NULL,  
    UserDefine10    DECIMAL(10, 2)   NULL,  
    UserDefine05    DECIMAL(10, 2)   NULL,  
    OrderLineNumber NVARCHAR(5)       NULL) 
  
   SELECT @c_UserDefine02 = ''  
   SELECT @c_TenderCode   = ''  
   SELECT @n_Count        = 0  
  
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
  
   INSERT INTO #ORDER  
   (C_contact1,   C_Address1,    C_Address2,    C_Address3,     
    C_Address4,   C_Country,     C_Zip,         EditDate,     ExternOrderKey,   
    RefNo,        Tender,        DropID,        Style,        DESCR,          
    Color,        Notes,         Size,          UnitPrice,    OrdersNotes,    
    Qty,          UserDefine04,  UserDefine10,  UserDefine05, OrderLineNumber) 
   SELECT ORDERS.C_contact1,       
         ORDERS.C_Address1,     
         ORDERS.C_Address2,     
         ORDERS.C_Address3,     
         ORDERS.C_Address4,     
         ORDERS.C_Country,   
         ORDERS.C_Zip,   
         MIN(ORDERDETAIL.EditDate) AS EditDate,     
         ORDERS.ExternOrderKey,     
         SPACE(20) AS RefNo,     
         @c_Tender,     
         ISNULL(RTRIM(PICKDETAIL.DropID), ''),  -- (Vicky02)   
         SKU.Style,     
         SKU.DESCR,     
         SKU.Color,     
         CASE WHEN PICKDETAIL.Status >= '5'  
              THEN ORDERDETAIL.UserDefine01  
         ELSE 'Out Of Stock *' END AS Notes,              
         SKU.Size,     
         ORDERDETAIL.UnitPrice,  
     CAST(ORDERS.Notes AS NVARCHAR(250)) AS OrdersNotes,    
     CASE WHEN PICKDETAIL.STATUS < '5' THEN 0 ELSE ISNULL(SUM(PICKDETAIL.Qty), 0) END AS Qty,     
     CASE WHEN ISNUMERIC(ORDERS.UserDefine04) = 1   
              THEN ORDERS.UserDefine04  
         ELSE '0.00' END AS UserDefine04,    
     CASE WHEN ISNUMERIC(ORDERS.UserDefine10) = 1   
              THEN ORDERS.UserDefine10  
         ELSE '0.00' END AS UserDefine10,    
     CASE WHEN ISNUMERIC(ORDERS.UserDefine05) = 1   
              THEN ORDERS.UserDefine05  
         ELSE '0.00' END AS UserDefine05,  
         ORDERDETAIL.OrderLineNumber
   FROM ORDERS WITH (NOLOCK)     
   JOIN ORDERDETAIL WITH (NOLOCK) ON (ORDERS.OrderKey = ORDERDETAIL.OrderKey)    
   JOIN SKU WITH (NOLOCK)         ON (ORDERDETAIL.StorerKey = SKU.StorerKey   
                                  AND ORDERDETAIL.Sku = SKU.Sku)   
   LEFT OUTER JOIN PICKDETAIL WITH (NOLOCK) ON ( ORDERDETAIL.OrderKey = PICKDETAIL.OrderKey  -- (Vicky02)
                                                 AND ORDERDETAIL.OrderLineNumber = PICKDETAIL.OrderLineNumber) -- (Vicky02)
--   JOIN (SELECT StorerKey, OrderKey, OrderLineNumber, DropID, Status,  
--                CASE WHEN Status >= '5'  
--                     THEN PICKDETAIL.Qty  
--                ELSE 0 END AS Qty  
--           FROM PICKDETAIL WITH (NOLOCK)) PICKDETAIL ON (ORDERDETAIL.StorerKey = PICKDETAIL.StorerKey   
--                                  AND ORDERDETAIL.OrderKey = PICKDETAIL.OrderKey  
--                                  AND ORDERDETAIL.OrderLineNumber = PICKDETAIL.OrderLineNumber)    
   
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
            ISNULL(RTRIM(PICKDETAIL.DropID), ''),    -- (Vicky02) 
            SKU.Style,     
            SKU.DESCR,     
            SKU.Color,     
            CASE WHEN PICKDETAIL.Status >= '5'  
                 THEN ORDERDETAIL.UserDefine01  
            ELSE 'Out Of Stock *' END,              
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
            ORDERDETAIL.OrderLineNumber, PICKDETAIL.STATUS
   
   DECLARE @c_DropID   NVARCHAR(18),
           @c_RefNo    NVARCHAR(20),
           @d_EditDate DATETIME
   
   DECLARE CUR_RESULT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT DropID 
   FROM   #ORDER ORD 
   WHERE DropID <> ''

   OPEN CUR_RESULT 
   
   FETCH NEXT FROM CUR_RESULT INTO @c_DropID  
   
   WHILE @@FETCH_STATUS <> -1
   BEGIN 

      -- (KHLim01)
      SELECT @cIncoTerm = ISNULL(RTRIM(IncoTerm),'')  
            ,@c_ExtOrderKey  = ExternOrderKey        -- (KHLim02)
      FROM  ORDERS WITH (NOLOCK)  
      WHERE Orderkey = @c_OrderKey  
      -- HDN LABEL
      IF EXISTS (SELECT 1 FROM dbo.Codelkup WITH (NOLOCK) WHERE Listname = 'HDNTERMS' AND Code = @cIncoTerm)  
      BEGIN  
         SET @cLabelType = 'HDNLABEL'  
      END  
      ELSE  
      BEGIN  
         --DPD LABEL
         IF EXISTS (SELECT 1 FROM RDT.rdtReport WITH (NOLOCK) 
                    WHERE StorerKey = @c_StorerKey AND ReportType = 'DPDLABEL')  
         BEGIN  
            SET @cLabelType = 'DUMMYLABEL' -- Dummy DPD LABEL
         END
         ELSE
         BEGIN
            SET @cEUCountry = 'N'  
            SELECT TOP 1 @cEUCountry = ISNULL(RTRIM(EUCountry),'N')   
            FROM dbo.REPDPDCNT REPDPDCNT WITH (NOLOCK)
            JOIN dbo.ORDERS ORDERS WITH (NOLOCK) ON (ORDERS.CountryDestination = REPDPDCNT.IATAcode)  -- (james01)
            WHERE ORDERS.Orderkey = @c_OrderKey  
     
            IF @cEUCountry = 'N'  
            BEGIN  
               SET @cLabelType = 'NDPDLABEL' -- National DPD LABEL
            END  
            ELSE  
            BEGIN  
               SET @cLabelType = 'EDPDLABEL' -- Europe DPD LABEL
            END
         END
      END  

      IF @cLabelType = 'DUMMYLABEL' -- (KHLim01)
      BEGIN
         SET @c_RefNo = @c_ExtOrderKey -- (KHLim02)
      END
      ELSE IF @cLabelType = 'HDNLABEL' -- (KHLim01)
      BEGIN
         SELECT TOP 1 @c_RefNo = PIF.RefNo, -- (Vicky02)
                      @d_EditDate = PD.EditDate 
         FROM PackDetail PD WITH (NOLOCK)
         JOIN PackHeader PH WITH (NOLOCK) ON (PD.PickSlipNo = PH.PickSlipNo)   
         JOIN PackInfo   PIF WITH (NOLOCK) ON (PIF.PickSlipNo = PD.PickSlipNo)
         WHERE PD.StorerKey = @c_StorerKey  
         AND   PD.DropID = @c_DropID  
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
               SET @c_errmsg = 'FAIL To Generate Parcel Number. isp_DeliveryOrder03'
               --GOTO QUIT
            END 
         END
         IF @cLabelType = 'NDPDLABEL'
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
            SET @c_errmsg = 'FAIL To Check Digit for Parcel Number:' + @c_RefNo + ' isp_DeliveryOrder03'
            --GOTO QUIT
         END 
         SET @c_RefNo = RTRIM(@c_RefNo) + @c_cdigit
      END

      UPDATE #ORDER
         SET RefNo = ISNULL(RTRIM(@c_RefNo), '')
      
      FETCH NEXT FROM CUR_RESULT INTO @c_DropID 
   END 
   
   SELECT * FROM #ORDER (NOLOCK) ORDER BY DROPID DESC   -- (KHLim01)
   DROP TABLE #ORDER    
END

GO