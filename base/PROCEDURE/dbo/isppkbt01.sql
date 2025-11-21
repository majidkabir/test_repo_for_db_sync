SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: ispPKBT01                                          */  
/* Creation Date: 27-Jul-2015                                           */  
/* Copyright: LF                                                        */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose: SOS#346367 - Packing module print to bartender              */  
/*                                                                      */  
/* Called By: Packing                                                   */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author   Ver  Purposes                                  */  
/************************************************************************/   
CREATE PROCEDURE [dbo].[ispPKBT01]
   @c_printerid  NVARCHAR(50) = '',  
   @c_labeltype  NVARCHAR(30) = '',  
   @c_userid     NVARCHAR(18) = '',  
   @c_Parm01     NVARCHAR(60) = '', --Pickslipno         
   @c_Parm02     NVARCHAR(60) = '', --carton from         
   @c_Parm03     NVARCHAR(60) = '', --carton to         
   @c_Parm04     NVARCHAR(60) = '',          
   @c_Parm05     NVARCHAR(60) = '',          
   @c_Parm06     NVARCHAR(60) = '',          
   @c_Parm07     NVARCHAR(60) = '',          
   @c_Parm08     NVARCHAR(60) = '',          
   @c_Parm09     NVARCHAR(60) = '',          
   @c_Parm10     NVARCHAR(60) = '',    
   @c_Storerkey  NVARCHAR(15) = '',
   @c_NoOfCopy   NVARCHAR(5) = '1',
   @c_Subtype    NVARCHAR(20) = '',
   @b_Success    INT      OUTPUT,
   @n_Err        INT      OUTPUT, 
   @c_ErrMsg     NVARCHAR(250) OUTPUT   
AS  
BEGIN  
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
      
   DECLARE @n_continue        INT,
           @c_SPCode          NVARCHAR(10),
           @c_SQL             NVARCHAR(MAX),
           @c_Pickslipno      NVARCHAR(10),
           @c_Orderkey        NVARCHAR(10),
           @c_OrderType       NVARCHAR(10),
           @c_Loadkey         NVARCHAR(10),
           @c_OrderCCountry   NVARCHAR(30),
           @c_VASType         NVARCHAR(10),
           @c_Field01         NVARCHAR(10), 
           @c_CodeTwo         NVARCHAR(30),
           @c_TemplateCode    NVARCHAR(60),
           @c_datawindow      NVARCHAR(100),
           @c_Facility        NVARCHAR(5),
           @n_TotalPickQty    INT,
           @n_TotalPackQty    INT,
           @c_printerid_paper NVARCHAR(50),
           @n_MaxCarton       INT
                                                      
   SELECT @n_err = 0, @b_success = 1, @c_errmsg = '', @n_continue = 1
   
   /*
   SELECT @c_userid = SUSER_SNAME()

   SELECT TOP 1 @c_printerid = U.DefaultPrinter
   FROM RDT.RDTUser U (NOLOCK)
   JOIN RDT.RDTPrinter P (NOLOCK) ON U.DefaultPrinter = P.PrinterID
   WHERE U.UserName = @c_userid   
   */
   
   IF @c_Subtype NOT IN ('UCCLABEL','UCCLbConso')
   BEGIN
      EXEC isp_BT_GenBartenderCommand   	  
              @cPrinterID = @c_PrinterID
             ,@c_LabelType = @c_LabelType
             ,@c_userid = @c_UserId
             ,@c_Parm01 = @c_Parm01 --pickslipno
             ,@c_Parm02 = @c_Parm02 --carton from
             ,@c_Parm03 = @c_Parm03 --carton to
             ,@c_Parm04 = @c_Parm04 --template code
             ,@c_Parm05 = @c_Parm05
             ,@c_Parm06 = @c_Parm06
             ,@c_Parm07 = @c_Parm07
             ,@c_Parm08 = @c_Parm08
             ,@c_Parm09 = @c_Parm09
             ,@c_Parm10 = @c_Parm10
             ,@c_Storerkey = @c_Storerkey
             ,@c_NoCopy = @c_NoOfCopy
             ,@c_Returnresult = 'N' 
             ,@n_err = @n_Err OUTPUT
             ,@c_errmsg = @c_ErrMsg OUTPUT   	
                               
      IF @n_Err <> 0 
      BEGIN
      	 SELECT @n_continue = 3
      END       
      
      GOTO QUIT_SP   
   END
   
   SET @c_Pickslipno = @c_Parm01
   
   SELECT @c_OrderKey = ORDERS.OrderKey,
          @c_OrderType = ORDERS.Type,
          @c_OrderCCountry = ORDERS.C_Country,
          @c_Loadkey = ORDERS.Loadkey,
          @c_Facility = ORDERS.Facility
   FROM PACKHEADER (NOLOCK)
   JOIN ORDERS (NOLOCK) ON PACKHEADER.Orderkey = ORDERS.Orderkey
   WHERE PACKHEADER.PickSlipNo = @c_PickSlipNo 

   IF EXISTS (SELECT 1 
              FROM dbo.DocInfo WITH (NOLOCK)
              WHERE StorerKey = @c_StorerKey
              AND Key1 = @c_OrderKey
              AND Rtrim(Substring(Docinfo.Data,31,30)) = 'L01') 
   BEGIN      
      DECLARE CursorLabel CURSOR LOCAL FAST_FORWARD READ_ONLY FOR           
         SELECT Rtrim(Substring(Docinfo.Data,31,30)) 
               ,Rtrim(Substring(Docinfo.Data,61,30))
         FROM dbo.DocInfo WITH (NOLOCK)
         WHERE StorerKey = @c_StorerKey
         AND Key1 = @c_OrderKey 
         AND Key2 = '00001'
         AND Rtrim(Substring(Docinfo.Data,31,30)) = 'L01'
         
      OPEN CursorLabel            
      
      FETCH NEXT FROM CursorLabel INTO @c_VASType, @c_Field01
            
      WHILE @@FETCH_STATUS <> -1     
      BEGIN         
         DECLARE CursorCodeLkup CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT Code2
            FROM dbo.CodeLkup WITH (NOLOCK)
            WHERE ListName = 'UALabel'
            AND Code  = @c_Field01
            AND Short = @c_VASType
            AND StorerKey = @c_StorerKey
         
         OPEN CursorCodeLkup
         FETCH NEXT FROM CursorCodeLkup INTO @c_CodeTwo
         WHILE @@FETCH_STATUS <> -1
         BEGIN                        
            SET @c_TemplateCode = ''
            SET @c_TemplateCode = ISNULL(RTRIM(@c_Field01),'')  + ISNULL(RTRIM(@c_CodeTwo),'') 
            
            IF @c_TemplateCode = '' 
            BEGIN
               SELECT @n_continue = 3  
               SELECT @c_ErrMsg = CONVERT(CHAR(250), @n_Err),
                      @n_Err = 31100 -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
               SELECT @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + 
                      ': No Label Template (ispPKBT01)'  
               GOTO QUIT_SP    
            END
            
            SELECT @c_Parm04 = @c_TemplateCode
            
 	          EXEC isp_BT_GenBartenderCommand   	  
                  @cPrinterID = @c_PrinterID
                 ,@c_LabelType = @c_LabelType
                 ,@c_userid = @c_UserId
                 ,@c_Parm01 = @c_Parm01 --pickslipno
                 ,@c_Parm02 = @c_Parm02 --carton from
                 ,@c_Parm03 = @c_Parm03 --carton to
                 ,@c_Parm04 = @c_Parm04 --template code
                 ,@c_Parm05 = @c_Parm05
                 ,@c_Parm06 = @c_Parm06
                 ,@c_Parm07 = @c_Parm07
                 ,@c_Parm08 = @c_Parm08
                 ,@c_Parm09 = @c_Parm09
                 ,@c_Parm10 = @c_Parm10
                 ,@c_Storerkey = @c_Storerkey
                 ,@c_NoCopy = @c_NoOfCopy
                 ,@c_Returnresult = 'N' 
                 ,@n_err = @n_Err OUTPUT
                 ,@c_errmsg = @c_ErrMsg OUTPUT   	
                                   
            IF @n_Err <> 0 
            BEGIN
            	 SELECT @n_continue = 3
               GOTO QUIT_SP   
            END
         
            FETCH NEXT FROM CursorCodeLkup INTO @c_CodeTwo
         END
         CLOSE CursorCodeLkup
         DEALLOCATE CursorCodeLkup
           
         FETCH NEXT FROM CursorLabel INTO @c_VASType, @c_Field01         
      END
      CLOSE CursorLabel            
      DEALLOCATE CursorLabel     
   END

   IF EXISTS (SELECT 1 
              FROM dbo.DocInfo WITH (NOLOCK)
              WHERE StorerKey = @c_StorerKey
              AND Key1 = @c_OrderKey
              AND Rtrim(Substring(Docinfo.Data,31,30)) = 'L02') 
   BEGIN      
      DECLARE CursorLabel2 CURSOR LOCAL FAST_FORWARD READ_ONLY FOR          
      SELECT Rtrim(Substring(Docinfo.Data,31,30)) 
      FROM dbo.DocInfo WITH (NOLOCK)
      WHERE StorerKey = @c_StorerKey
      AND Key1 = @c_OrderKey 
      AND Key2 = '00001'
      AND Rtrim(Substring(Docinfo.Data,31,30)) = 'L02'
      
      OPEN CursorLabel2            
      
      FETCH NEXT FROM CursorLabel2 INTO @c_VASType
            
      WHILE @@FETCH_STATUS <> -1     
      BEGIN         
         DECLARE CursorCodeLkup2 CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT Code2
         FROM dbo.CodeLkup WITH (NOLOCK)
         WHERE ListName = 'UACCLabel'
         AND Code  = @c_VASType
         AND StorerKey = @c_StorerKey
         
         OPEN CursorCodeLkup2
         FETCH NEXT FROM CursorCodeLkup2 INTO @c_CodeTwo
         WHILE @@FETCH_STATUS <> -1
         BEGIN
                        
            SET @c_TemplateCode = ''
            SET @c_TemplateCode = ISNULL(RTRIM(@c_VASType),'')  + ISNULL(RTRIM(@c_CodeTwo),'') 
            
            IF @c_TemplateCode = '' 
            BEGIN
               SELECT @n_continue = 3  
               SELECT @c_ErrMsg = CONVERT(CHAR(250), @n_Err),
                      @n_Err = 31110 -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
               SELECT @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + 
                      ': No Label Template (ispPKBT01)'  
               GOTO QUIT_SP    
            END
            
            SELECT @c_Parm04 = @c_TemplateCode
            
 	          EXEC isp_BT_GenBartenderCommand   	  
                  @cPrinterID = @c_PrinterID
                 ,@c_LabelType = @c_LabelType
                 ,@c_userid = @c_UserId
                 ,@c_Parm01 = @c_Parm01 --pickslipno
                 ,@c_Parm02 = @c_Parm02 --carton from
                 ,@c_Parm03 = @c_Parm03 --carton to
                 ,@c_Parm04 = @c_Parm04 --template code
                 ,@c_Parm05 = @c_Parm05
                 ,@c_Parm06 = @c_Parm06
                 ,@c_Parm07 = @c_Parm07
                 ,@c_Parm08 = @c_Parm08
                 ,@c_Parm09 = @c_Parm09
                 ,@c_Parm10 = @c_Parm10
                 ,@c_Storerkey = @c_Storerkey
                 ,@c_NoCopy = @c_NoOfCopy
                 ,@c_Returnresult = 'N' 
                 ,@n_err = @n_Err OUTPUT
                 ,@c_errmsg = @c_ErrMsg OUTPUT   	
                                   
            IF @n_Err <> 0 
            BEGIN
            	 SELECT @n_continue = 3
               GOTO QUIT_SP   
            END
         
            FETCH NEXT FROM CursorCodeLkup2 INTO @c_CodeTwo
         END
         CLOSE CursorCodeLkup2
         DEALLOCATE CursorCodeLkup2
           
         FETCH NEXT FROM CursorLabel2 INTO @c_VASType    
      END
      CLOSE CursorLabel2            
      DEALLOCATE CursorLabel2     
   END

   SELECT TOP 1 @c_printerid_paper = U.DefaultPrinter_paper
   FROM RDT.RDTUser U (NOLOCK)
   JOIN RDT.RDTPrinter P (NOLOCK) ON U.DefaultPrinter_Paper = P.PrinterID
   WHERE U.UserName = @c_userid
   
   IF ISNULL(@c_printerid_paper,'') <> ''
   BEGIN
      SELECT @n_TotalPickQty = SUM(Qty)
      FROM PICKDETAIL(NOLOCK)
      WHERE Orderkey = @c_Orderkey
      
      SELECT @n_TotalPackQty = SUM(Qty),
             @n_MaxCarton = MAX(Cartonno)
      FROM PACKDETAIL(NOLOCK)
      WHERE Pickslipno = @c_Pickslipno
         
      IF EXISTS (SELECT 1 
                 FROM dbo.DocInfo WITH (NOLOCK)
                 WHERE StorerKey = @c_StorerKey
                 AND Key1 = @c_OrderKey
                 AND Rtrim(Substring(Docinfo.Data,31,30)) = 'F01')  
         AND (@n_TotalPickQty = @n_TotalPackQty) AND ((@n_TotalPickQty + @n_TotalPackQty) > 0)
         AND (@n_MaxCarton = CAST(@c_Parm03 AS INT))  --last carton
      BEGIN      
      	  SET @c_VASType = ''
         SET @c_Datawindow = ''
      	  
         SELECT @c_VASType = Rtrim(Substring(Docinfo.Data,31,30)) 
         FROM dbo.DocInfo WITH (NOLOCK)
         WHERE StorerKey = @c_StorerKey
         AND Key1 = @c_OrderKey 
         AND Key2 = '00001'
         AND Rtrim(Substring(Docinfo.Data,31,30)) = 'F01'      
         
         SELECT @c_Datawindow = Notes
         FROM dbo.CodeLkup WITH (NOLOCK)
         WHERE ListName = 'UAPACKLIST'
         AND Code  = @c_VASType
         AND StorerKey = @c_StorerKey
         
         IF ISNULL(@c_Datawindow,'') <> ''
         BEGIN      	   	        	
           EXEC isp_PrintToRDTSpooler 
                @c_ReportType = 'PACKLIST', 
                @c_Storerkey  = @c_Storerkey,
                @b_success		 = @b_success OUTPUT,
                @n_err			   = @n_err OUTPUT,
                @c_errmsg	   = @c_errmsg OUTPUT,
                @n_Noofparam  = 1,
                @c_Param01    = @c_PickSlipNo,
                @c_Param02    = '',
                @c_Param03    = '',
                @c_Param04    = '',
                @c_Param05    = '',
                @c_Param06    = '',
                @c_Param07    = '',
                @c_Param08    = '',
                @c_Param09    = '',
                @c_Param10    = '',
                @n_Noofcopy   = 1,
                @c_UserName   = @c_userid,
                @c_Facility   = @c_facility,
                @c_PrinterID  = @c_printerid_paper,
                @c_Datawindow = @c_Datawindow,
                @c_IsPaperPrinter = 'Y'
      
               IF @b_success <> 1 
               BEGIN
               	 SELECT @n_continue = 3
                  GOTO QUIT_SP   
               END
         END  
      END
   END
                      
   QUIT_SP:
   IF @n_continue = 3
   BEGIN
       SELECT @b_success = 0
       EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'ispPKBT01'  
       RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
   END   
END  

GO