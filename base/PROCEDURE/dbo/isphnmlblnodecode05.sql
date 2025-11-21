SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: ispHnMLblNoDecode05                                 */  
/* Copyright      : IDS                                                 */  
/*                                                                      */  
/* Purpose: Decode Label No Scanned                                     */  
/*                                                                      */  
/* Called from:                                                         */  
/*                                                                      */  
/* Exceed version: 5.4                                                  */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date        Rev  Author      Purposes                                */  
/* 2019-11-13  1.0  James       Temp fix for D11. If lottable02 not     */  
/*                              match with scanned barcode then return  */  
/*                              allocated lottable02 value. System only */  
/*                              match orders+sku+qty                    */  
/* 2021-02-18  1.1  James       WMS-16145 Move orders must match Lot02  */
/************************************************************************/  
  
CREATE PROCEDURE [dbo].[ispHnMLblNoDecode05]  
   @c_LabelNo          NVARCHAR(40),    
   @c_Storerkey        NVARCHAR(15),    
   @c_ReceiptKey       NVARCHAR(10),    
   @c_POKey            NVARCHAR(10),    
   @c_LangCode         NVARCHAR(3),    
   @c_oFieled01        NVARCHAR(20) OUTPUT,    
   @c_oFieled02        NVARCHAR(20) OUTPUT,    
   @c_oFieled03        NVARCHAR(20) OUTPUT,    
   @c_oFieled04        NVARCHAR(20) OUTPUT,    
   @c_oFieled05        NVARCHAR(20) OUTPUT,    
   @c_oFieled06        NVARCHAR(20) OUTPUT,    
   @c_oFieled07        NVARCHAR(20) OUTPUT,    
   @c_oFieled08        NVARCHAR(20) OUTPUT,    
   @c_oFieled09        NVARCHAR(20) OUTPUT,    
   @c_oFieled10        NVARCHAR(20) OUTPUT,    
   @b_Success          INT = 1  OUTPUT,    
   @n_ErrNo            INT      OUTPUT,     
   @c_ErrMsg           NVARCHAR(250) OUTPUT    
AS    
BEGIN    
   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
    
   DECLARE @n_LblLength             INT,     
           @c_OrderKey              NVARCHAR( 10),     
           @c_SKU                   NVARCHAR( 20),     
           @c_Lottable01            NVARCHAR( 18),     
           @c_Lottable02            NVARCHAR( 18),     
           @c_Lottable03            NVARCHAR( 18),     
           @d_Lottable04            DATETIME,     
           @c_ShowErrMsgInNewScn    NVARCHAR( 1),     
           @n_Func                  INT,     
           @n_Mobile                INT,    
           @c_DecodeUCCNo      NVARCHAR( 1)    
    
   DECLARE @cErrMsg1    NVARCHAR( 20), @cErrMsg2    NVARCHAR( 20),    
           @cErrMsg3    NVARCHAR( 20), @cErrMsg4    NVARCHAR( 20),    
           @cErrMsg5    NVARCHAR( 20), @cErrMsg6    NVARCHAR( 20),    
           @cErrMsg7    NVARCHAR( 20), @cErrMsg8    NVARCHAR( 20),    
           @cErrMsg9    NVARCHAR( 20), @cErrMsg10   NVARCHAR( 20),    
           @cErrMsg11   NVARCHAR( 20), @cErrMsg12   NVARCHAR( 20),    
           @cErrMsg13   NVARCHAR( 20), @cErrMsg14   NVARCHAR( 20),    
           @cErrMsg15   NVARCHAR( 20)     
    
   SELECT @n_Func = Func, @n_Mobile = Mobile FROM RDT.RDTMOBREC WITH (NOLOCK) WHERE UserName = sUSER_SNAME()    
     
   IF @n_Func = 840  
   BEGIN  
      SET @c_DecodeUCCNo = rdt.RDTGetConfig( @n_Func, 'DecodeUCCNo', @c_Storerkey)    
    
      IF @c_DecodeUCCNo = '1'    
         SET @c_LabelNo = RIGHT( @c_LabelNo, LEN(@c_LabelNo) - 2)    
    
      SET @c_ShowErrMsgInNewScn = rdt.RDTGetConfig( @n_Func, 'ShowErrMsgInNewScn', @c_Storerkey)    
      IF @c_ShowErrMsgInNewScn = '0'    
         SET @c_ShowErrMsgInNewScn = ''          
    
      
      SET @n_ErrNo = 0    
      SET @c_OrderKey = @c_ReceiptKey    
    
      IF ISNULL( @c_OrderKey, '') = ''    
      BEGIN    
         SET @c_ErrMsg = 'Invalid Order'    
         GOTO Quit    
      END    
    
      SET @n_LblLength = 0    
      SET @n_LblLength = LEN(ISNULL(RTRIM(@c_LabelNo),''))    
    
      IF @n_LblLength = 0 OR @n_LblLength > 29    
      BEGIN    
         SET @c_ErrMsg = 'Invalid SKU'   --Return Error    
         GOTO Quit    
      END    
       
      SET @c_SKU = SUBSTRING( RTRIM( @c_LabelNo), 3, 13) -- SKU    
      SET @c_Lottable02 = SUBSTRING( RTRIM( @c_LabelNo), 16, 12) -- Lottable02    
      SET @c_Lottable02 = RTRIM( @c_Lottable02) + '-' -- Lottable02    
      SET @c_Lottable02 = RTRIM( @c_Lottable02) + SUBSTRING( RTRIM( @c_LabelNo), 28, 2) -- Lottable02    
    
      IF NOT EXISTS ( SELECT 1 FROM dbo.PickDetail WITH (NOLOCK)     
                      WHERE StorerKey = @c_Storerkey    
                      AND   OrderKey = @c_OrderKey    
                      AND   SKU = @c_SKU    
                      AND   [Status] < '9')    
      BEGIN    
         SET @c_ErrMsg = 'Invalid SKU'   --Return Error    
         GOTO Quit    
      END    
    
     
      IF NOT EXISTS ( SELECT 1 FROM dbo.LotAttribute WITH (NOLOCK)   
                      WHERE StorerKey = @c_StorerKey  
                      AND   SKU = @c_SKU  
                      AND   Lottable02 = @c_Lottable02)  
      BEGIN  
         -- If it is a Move type orders then Lot02 must match    
         IF EXISTS ( SELECT 1 FROM dbo.CODELKUP C WITH (NOLOCK)     
                     JOIN dbo.Orders O WITH (NOLOCK) ON (C.Code = O.Type AND C.StorerKey = O.StorerKey)    
                     WHERE C.ListName = 'HMORDTYPE'    
                     AND   C.UDF01 = 'M'    
                     AND   O.OrderKey = @c_OrderKey    
                     AND   O.StorerKey = @c_Storerkey)    
         BEGIN  
            SET @c_ErrMsg = 'Invalid Lot02'   --Return Error  
            GOTO Quit  
         END  
         ELSE
         BEGIN
            SELECT TOP 1 @c_Lottable02 = l.Lottable02  
            FROM dbo.PICKDETAIL AS p WITH (NOLOCK)   
            JOIN dbo.LOTATTRIBUTE AS l WITH (NOLOCK) ON ( p.Lot = l.Lot)  
            WHERE p.Storerkey = @c_Storerkey  
            AND   p.OrderKey = @c_OrderKey  
            AND   p.Sku = @c_SKU  
            AND   p.QtyMoved = '0'  
            AND   p.[Status] < '9'  
            ORDER BY 1  
        
            IF @@ROWCOUNT = 0  
            BEGIN  
               SET @c_ErrMsg = 'Invalid Lot02'   --Return Error  
               GOTO Quit  
            END
         END  
      END  
    
      SET @c_oFieled01 = @c_SKU    
      SET @c_oFieled02 = @c_Lottable02    
   END  
     
   IF @n_Func = 841  
   BEGIN  
      SET @c_ShowErrMsgInNewScn = rdt.RDTGetConfig( @n_Func, 'ShowErrMsgInNewScn', @c_Storerkey)    
      IF @c_ShowErrMsgInNewScn = '0'    
         SET @c_ShowErrMsgInNewScn = ''          
    
               
      SET @n_ErrNo = 0    
      SET @c_OrderKey = @c_ReceiptKey    
       
      SET @n_LblLength = 0    
      SET @n_LblLength = LEN(ISNULL(RTRIM(@c_LabelNo),''))    
    
      IF @n_LblLength = 0 OR @n_LblLength > 29    
      BEGIN    
         SET @n_ErrNo = 131801    
         SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @c_LangCode, 'DSP') --Invalid SKU    
         GOTO Quit    
      END    
       
      SET @c_SKU = SUBSTRING( RTRIM( @c_LabelNo), 3, 13) -- SKU    
      SET @c_Lottable02 = SUBSTRING( RTRIM( @c_LabelNo), 16, 12) -- Lottable02    
      SET @c_Lottable02 = RTRIM( @c_Lottable02) + '-' -- Lottable02    
      SET @c_Lottable02 = RTRIM( @c_Lottable02) + SUBSTRING( RTRIM( @c_LabelNo), 28, 2) -- Lottable02    
    
      SET @c_oFieled01 = @c_SKU    
      SET @c_oFieled02 = @c_Lottable02    
   END  
   Quit:      
    
    
END -- End Procedure    

GO