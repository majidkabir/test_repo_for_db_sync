SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/*********************************************************************************/  
/* Stored Procedure: isp_XLGen_EmailInfo_CNWMS_Porsche_GoodsOut                  */  
/* Creation Date: 14-Apr-2020                                                    */  
/* Copyright: LFL                                                                */  
/* Written by: TKLIM                                                             */  
/*                                                                               */  
/* Purpose: Construct and Return EmailTo, EmailCC, EmailSubject and EmailBody    */  
/*                                                                               */  
/* Called By: AutoSendEmail                                                      */  
/*                                                                               */  
/* PVCS Version: 1.0                                                             */  
/*                                                                               */  
/* Updates:                                                                      */  
/* Date         Author   Ver        Purposes                                     */  
/* 14-Apr-2020  TKLIM    1.0.0.0    Initial Development                          */  
/*********************************************************************************/  
  
CREATE PROC [dbo].[isp_XLGen_EmailInfo_CNWMS_Porsche_GoodsOut]  
(  
   @c_Key1           NVARCHAR(100)    
,  @c_Key2           NVARCHAR(100)  
  
)  
AS  
BEGIN  
   SET NOCOUNT ON   
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF    
           
   /*********************************************/  
   /* Variables Declaration (Start)             */  
   /*********************************************/  
  
   DECLARE  @c_EmailBody      NVARCHAR(MAX)  
          , @c_EmailSubject   NVARCHAR(200)  
  
   SET @c_EmailSubject  = N'Porsche_Goods_Out_notice (' + @c_Key2 + ')'  
   SET @c_EmailBody     = N'<font face="Calibri">To whom it might concern,</font><br>'  
                        + N'<font face="Microsoft YaHei">诸位，</font><br>'  
                        + N'<br>'  
                        + N'<font face="Calibri">This is just a kind notice that the orders that you have placed to Porsche China Marketing warehouse, has been sent out for you, with details shown as attached, for your reference.</font><br>'  
                        + N'<font face="Microsoft YaHei">很高兴地通知您，您向保时捷中国市场部仓库下的采购订单已被寄出，详细内容参考见本邮件附件产品清单。</font><br>'  
                        + N'<br>'  
                        + N'<font face="Calibri">The estimated arrival date is within 5 working days after this email. Before signing the delivery note, please do get your authorized staff to check whether the original carton seal is in good condition and
 count the quantity of the goods inside of the package.</font><br>'  
                        + N'<font face="Microsoft YaHei">大致到货时间为您收到此邮件的5个工作日以内. 在签署配送单据之前, 请务必安排贵公司授权人员注意查收货物，仔细检查原包装封签是否完好无损并核对清点包装内货物数量。</font><br>'  
                        + N'<br>'  
                        + N'<font face="Calibri">As a partner of Porsche China, LF Logistics China is glad to be at your services and assist your business, and feel free to contact below person, if any help needed.</font><br>'  
                        + N'<font face="Microsoft YaHei">作为保时捷中国的服务伙伴，利丰供应链管理（中国）有限公司非常乐于为您提供服务促进您的业务增长，若对我们的服务有任何需要，请随时联系以下人员。</font><br>'  
                        + N'<br>'  
                        + N'<font face="Calibri">Contact person of LF Logistics China:</font><br>'  
                        + N'<font face="Microsoft YaHei">利丰供应链管理（中国）有限公司，联系人：</font><br>'  
                        + N'<br>'  
                        + N'<font face="Calibri">Mr. Max Wang +86 13761114624, E-mail: LFLPorscheDC@lflogistics.com, project supervisor of LF logistics China services, for Porsche China Marketing/dealership support project.</font><br>'  
                        + N'<font face="Microsoft YaHei">Mr. Max Wang +86 13761114624, E-mail: LFLPorscheDC@lflogistics.com, 利丰供应链管理（中国）有限公司项目主管，保时捷市场及经销商支持项目。</font><br>'  
                        + N'<br>'  
                        + N'<font face="Calibri">Please note, this email is only a kind notice of the coming shipment, should there be any differences or problems upon the orders with the actual goods, please do contact us .Further claims will be rejected
 if there is no goods damage or other abnormalities which are written on the Proof of Delivery when goods are accepted. If the inside packing is not checked because the carton cannot be opened on site, please write the following words “内箱未检查”on the Proof 
of Delivery and claim the discrepancy or other exceptions within 2 working days. Please note that it is a must to open package of “fragile cargo” to check inside cargo when the package is received; otherwise further claim will also be rejected.</font><br>
'  
                        + N'<font face="Microsoft YaHei">友善提醒，本邮件仅作为即将到货的告知，如果实际到货与您的订单有差异或者问题，请立即与我们联系，如果接收货物的时候不签收破损或者其他异常，后期不予以索赔。现场如无法开箱，内包装未检查，请在签收单上注明：“内箱未检查”，事后如有发现内箱差异或其它异常，须在签收后的2工作天内与我们联系反馈。对于易碎品货物，必须现场开箱检查，如果易碎品现场没有开箱检查，后期不予索赔。</font><br>'  
                        + N'<br>'  
                        + N'<font face="Calibri">If you need copy of POD, please sent the order no to LFLPorscheDC@lflogistics.com for help.</font><br>'  
                        + N'<font face="Microsoft YaHei">如果需要提供签收单扫描件，请发送订单号至LFLPorscheDC@lflogistics.com, 进行查询。</font><br>'  
  
   /********************************************/  
   /* Variables Declaration (END)              */  
   /********************************************/  
  
   --GET EmailTo  
   SELECT ISNULL(RTRIM(M_Address2),'')       [EmailTo]  
        , ''               [EmailCC]  
        , @c_EmailSubject  [EmailSubject]  
        , @c_EmailBody     [EmailBody]  
   FROM Orders (NOLOCK)  
   WHERE OrderKey = @c_Key1   
   AND ExternOrderkey = @c_Key2   
  
   --SELECT 'CaiYunChen@LFLogistics.com'       [EmailTo]  
   --     , 'limtzekeong@lflogistics.com'      [EmailCC]  
   --     , @c_EmailSubject  [EmailSubject]  
   --     , @c_EmailBody     [EmailBody]  
   --FROM Orders (NOLOCK)  
   --WHERE OrderKey = @c_Key1   
   --AND ExternOrderkey = @c_Key2  
                                     
END -- End of Procedure

GO